import { create } from 'zustand';
import type { Project, Task } from '@/types';
import * as api from '@/api/endpoints';
import { debounce, normalizeProject } from '@/utils';

interface ProjectState {
  // 状态
  currentProject: Project | null;
  isGlobalLoading: boolean;
  activeTaskId: string | null;
  taskProgress: { total: number; completed: number } | null;
  error: string | null;

  // Actions
  setCurrentProject: (project: Project | null) => void;
  setGlobalLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  
  // 项目操作
  initializeProject: (type: 'idea' | 'outline' | 'description', content: string, templateImage?: File) => Promise<void>;
  syncProject: (projectId?: string) => Promise<void>;
  
  // 页面操作
  updatePageLocal: (pageId: string, data: any) => void;
  reorderPages: (newOrder: string[]) => Promise<void>;
  addNewPage: () => Promise<void>;
  deletePageById: (pageId: string) => Promise<void>;
  
  // 异步任务
  startAsyncTask: (apiCall: () => Promise<any>) => Promise<void>;
  pollTask: (taskId: string) => Promise<void>;
  
  // 生成操作
  generateOutline: () => Promise<void>;
  generateDescriptions: () => Promise<void>;
  generateImages: () => Promise<void>;
  generatePageImage: (pageId: string) => Promise<void>;
  editPageImage: (pageId: string, editPrompt: string) => Promise<void>;
  
  // 导出
  exportPPTX: () => Promise<void>;
  exportPDF: () => Promise<void>;
}

// 防抖的API更新函数
const debouncedUpdatePage = debounce(
  async (projectId: string, pageId: string, data: any) => {
    await api.updatePage(projectId, pageId, data);
  },
  1000
);

export const useProjectStore = create<ProjectState>((set, get) => ({
  // 初始状态
  currentProject: null,
  isGlobalLoading: false,
  activeTaskId: null,
  taskProgress: null,
  error: null,

  // Setters
  setCurrentProject: (project) => set({ currentProject: project }),
  setGlobalLoading: (loading) => set({ isGlobalLoading: loading }),
  setError: (error) => set({ error }),

  // 初始化项目
  initializeProject: async (type, content, templateImage) => {
    set({ isGlobalLoading: true, error: null });
    try {
      const request: any = {};
      
      if (type === 'idea') {
        request.idea_prompt = content;
      } else if (type === 'outline') {
        request.outline_text = content;
      } else if (type === 'description') {
        request.description_text = content;
      }
      
      // 1. 创建项目
      const response = await api.createProject(request);
      const projectId = response.data?.project_id;
      
      if (!projectId) {
        throw new Error('项目创建失败：未返回项目ID');
      }
      
      // 2. 如果有模板图片，上传模板
      if (templateImage) {
        try {
          await api.uploadTemplate(projectId, templateImage);
        } catch (error) {
          console.warn('模板上传失败:', error);
          // 模板上传失败不影响项目创建，继续执行
        }
      }
      
      // 3. 获取完整项目信息
      const projectResponse = await api.getProject(projectId);
      const project = normalizeProject(projectResponse.data);
      
      if (project) {
        set({ currentProject: project });
        // 保存到 localStorage
        localStorage.setItem('currentProjectId', project.id!);
      }
    } catch (error: any) {
      set({ error: error.message || '创建项目失败' });
      throw error;
    } finally {
      set({ isGlobalLoading: false });
    }
  },

  // 同步项目数据
  syncProject: async (projectId?: string) => {
    const { currentProject } = get();
    
    // 如果没有提供 projectId，尝试从 currentProject 或 localStorage 获取
    let targetProjectId = projectId;
    if (!targetProjectId) {
      if (currentProject?.id) {
        targetProjectId = currentProject.id;
      } else {
        targetProjectId = localStorage.getItem('currentProjectId') || undefined;
      }
    }
    
    if (!targetProjectId) {
      console.warn('syncProject: 没有可用的项目ID');
      return;
    }

    try {
      const response = await api.getProject(targetProjectId);
      if (response.data) {
        const project = normalizeProject(response.data);
        set({ currentProject: project });
        // 确保 localStorage 中保存了项目ID
        localStorage.setItem('currentProjectId', project.id!);
      }
    } catch (error: any) {
      set({ error: error.message || '同步项目失败' });
    }
  },

  // 本地更新页面（乐观更新）
  updatePageLocal: (pageId, data) => {
    const { currentProject } = get();
    if (!currentProject) return;

    const updatedPages = currentProject.pages.map((page) =>
      page.id === pageId ? { ...page, ...data } : page
    );

    set({
      currentProject: {
        ...currentProject,
        pages: updatedPages,
      },
    });

    // 防抖后调用API
    debouncedUpdatePage(currentProject.id, pageId, data);
  },

  // 重新排序页面
  reorderPages: async (newOrder) => {
    const { currentProject } = get();
    if (!currentProject) return;

    // 乐观更新
    const reorderedPages = newOrder
      .map((id) => currentProject.pages.find((p) => p.id === id))
      .filter(Boolean) as any[];

    set({
      currentProject: {
        ...currentProject,
        pages: reorderedPages,
      },
    });

    try {
      await api.updatePagesOrder(currentProject.id, newOrder);
    } catch (error: any) {
      set({ error: error.message || '更新顺序失败' });
      // 失败后重新同步
      await get().syncProject();
    }
  },

  // 添加新页面
  addNewPage: async () => {
    const { currentProject } = get();
    if (!currentProject) return;

    try {
      const newPage = {
        outline_content: { title: '新页面', points: [] },
        order_index: currentProject.pages.length,
      };
      
      const response = await api.addPage(currentProject.id, newPage);
      if (response.data) {
        await get().syncProject();
      }
    } catch (error: any) {
      set({ error: error.message || '添加页面失败' });
    }
  },

  // 删除页面
  deletePageById: async (pageId) => {
    const { currentProject } = get();
    if (!currentProject) return;

    try {
      await api.deletePage(currentProject.id, pageId);
      await get().syncProject();
    } catch (error: any) {
      set({ error: error.message || '删除页面失败' });
    }
  },

  // 启动异步任务
  startAsyncTask: async (apiCall) => {
    console.log('[异步任务] 启动异步任务...');
    set({ isGlobalLoading: true, error: null });
    try {
      const response = await apiCall();
      console.log('[异步任务] API响应:', response);
      
      // task_id 在 response.data 中
      const taskId = response.data?.task_id;
      if (taskId) {
        console.log('[异步任务] 收到task_id:', taskId, '开始轮询...');
        set({ activeTaskId: taskId });
        await get().pollTask(taskId);
      } else {
        console.warn('[异步任务] 响应中没有task_id:', response);
        set({ isGlobalLoading: false });
      }
    } catch (error: any) {
      console.error('[异步任务] 启动失败:', error);
      set({ error: error.message || '任务启动失败', isGlobalLoading: false });
      throw error;
    }
  },

  // 轮询任务状态
  pollTask: async (taskId) => {
    console.log(`[轮询] 开始轮询任务: ${taskId}`);
    const { currentProject } = get();
    if (!currentProject) {
      console.warn('[轮询] 没有当前项目，停止轮询');
      return;
    }

    const poll = async () => {
      try {
        console.log(`[轮询] 查询任务状态: ${taskId}`);
        const response = await api.getTaskStatus(currentProject.id!, taskId);
        const task = response.data;
        
        if (!task) {
          console.warn('[轮询] 响应中没有任务数据');
          return;
        }

        // 更新进度
        if (task.progress) {
          set({ taskProgress: task.progress });
        }

        console.log(`[轮询] Task ${taskId} 状态: ${task.status}`, task);

        // 检查任务状态
        if (task.status === 'COMPLETED') {
          console.log(`[轮询] Task ${taskId} 已完成，刷新项目数据`);
          set({ 
            activeTaskId: null, 
            taskProgress: null, 
            isGlobalLoading: false 
          });
          // 刷新项目数据
          await get().syncProject();
        } else if (task.status === 'FAILED') {
          console.error(`[轮询] Task ${taskId} 失败:`, task.error_message || task.error);
          set({ 
            error: task.error_message || task.error || '任务失败',
            activeTaskId: null,
            taskProgress: null,
            isGlobalLoading: false
          });
        } else if (task.status === 'PENDING' || task.status === 'PROCESSING') {
          // 继续轮询（PENDING 或 PROCESSING）
          console.log(`[轮询] Task ${taskId} 处理中，2秒后继续轮询...`);
          setTimeout(poll, 2000);
        } else {
          // 未知状态，停止轮询
          console.warn(`[轮询] Task ${taskId} 未知状态: ${task.status}，停止轮询`);
          set({ 
            error: `未知任务状态: ${task.status}`,
            activeTaskId: null,
            taskProgress: null,
            isGlobalLoading: false
          });
        }
      } catch (error: any) {
        console.error('任务轮询错误:', error);
        set({ 
          error: error.message || '任务查询失败',
          activeTaskId: null,
          isGlobalLoading: false
        });
      }
    };

    await poll();
  },

  // 生成大纲（同步操作，不需要轮询）
  generateOutline: async () => {
    const { currentProject } = get();
    if (!currentProject) return;

    set({ isGlobalLoading: true, error: null });
    try {
      await api.generateOutline(currentProject.id!);
      // 刷新项目数据
      await get().syncProject();
    } catch (error: any) {
      set({ error: error.message || '生成大纲失败' });
      throw error;
    } finally {
      set({ isGlobalLoading: false });
    }
  },

  // 生成描述
  generateDescriptions: async () => {
    const { currentProject, startAsyncTask } = get();
    if (!currentProject) return;

    await startAsyncTask(() => api.generateDescriptions(currentProject.id));
  },

  // 生成图片
  generateImages: async () => {
    const { currentProject, startAsyncTask } = get();
    if (!currentProject) return;

    await startAsyncTask(() => api.generateImages(currentProject.id));
  },

  // 生成单页图片
  generatePageImage: async (pageId) => {
    const { currentProject, startAsyncTask } = get();
    if (!currentProject) return;

    await startAsyncTask(() => api.generatePageImage(currentProject.id, pageId));
  },

  // 编辑页面图片
  editPageImage: async (pageId, editPrompt) => {
    const { currentProject, startAsyncTask } = get();
    if (!currentProject) return;

    await startAsyncTask(() => api.editPageImage(currentProject.id, pageId, editPrompt));
  },

  // 导出PPTX
  exportPPTX: async () => {
    const { currentProject } = get();
    if (!currentProject) return;

    set({ isGlobalLoading: true, error: null });
    try {
      const blob = await api.exportPPTX(currentProject.id);
      const { downloadFile } = await import('@/utils');
      downloadFile(blob, `${currentProject.idea_prompt.slice(0, 20)}.pptx`);
    } catch (error: any) {
      set({ error: error.message || '导出失败' });
    } finally {
      set({ isGlobalLoading: false });
    }
  },

  // 导出PDF
  exportPDF: async () => {
    const { currentProject } = get();
    if (!currentProject) return;

    set({ isGlobalLoading: true, error: null });
    try {
      const blob = await api.exportPDF(currentProject.id);
      const { downloadFile } = await import('@/utils');
      downloadFile(blob, `${currentProject.idea_prompt.slice(0, 20)}.pdf`);
    } catch (error: any) {
      set({ error: error.message || '导出失败' });
    } finally {
      set({ isGlobalLoading: false });
    }
  },
}));


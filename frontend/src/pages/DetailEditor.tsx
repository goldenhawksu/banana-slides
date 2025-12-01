import React, { useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, ArrowRight, Sparkles } from 'lucide-react';
import { Button, Loading } from '@/components/shared';
import { DescriptionCard } from '@/components/preview/DescriptionCard';
import { useProjectStore } from '@/store/useProjectStore';

export const DetailEditor: React.FC = () => {
  const navigate = useNavigate();
  const { projectId } = useParams<{ projectId: string }>();
  const {
    currentProject,
    syncProject,
    updatePageLocal,
    generateDescriptions,
    isGlobalLoading,
    taskProgress,
  } = useProjectStore();

  // 加载项目数据
  useEffect(() => {
    if (projectId && (!currentProject || currentProject.id !== projectId)) {
      // 直接使用 projectId 同步项目数据
      syncProject(projectId);
    }
  }, [projectId, currentProject, syncProject]);

  const handleGenerateAll = async () => {
    const hasDescriptions = currentProject?.pages.some(
      (p) => p.description_content
    );
    
    if (hasDescriptions) {
      if (!confirm('部分页面已有描述，重新生成将覆盖，确定继续吗？')) {
        return;
      }
    }
    
    await generateDescriptions();
  };

  const handleRegeneratePage = async (pageId: string) => {
    // TODO: 实现单页重新生成
    console.log('重新生成页面:', pageId);
  };

  if (!currentProject) {
    return <Loading fullscreen message="加载项目中..." />;
  }

  if (isGlobalLoading) {
    return (
      <Loading
        fullscreen
        message="生成页面描述中..."
        progress={taskProgress || undefined}
      />
    );
  }

  const hasAllDescriptions = currentProject.pages.every(
    (p) => p.description_content
  );

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* 顶栏 */}
      <header className="h-16 bg-white shadow-sm border-b border-gray-200 flex items-center justify-between px-6">
        <div className="flex items-center gap-4">
          <Button
            variant="ghost"
            size="sm"
            icon={<ArrowLeft size={18} />}
            onClick={() => navigate(`/project/${projectId}/outline`)}
          >
            返回
          </Button>
          <div className="flex items-center gap-2">
            <span className="text-2xl">🍌</span>
            <span className="text-xl font-bold">蕉幻</span>
          </div>
          <span className="text-gray-400">|</span>
          <span className="text-lg font-semibold">编辑页面描述</span>
        </div>
        <div className="flex items-center gap-3">
          <Button
            variant="secondary"
            size="sm"
            icon={<ArrowLeft size={18} />}
            onClick={() => navigate(`/project/${projectId}/outline`)}
          >
            上一步
          </Button>
          <Button
            variant="primary"
            size="sm"
            icon={<ArrowRight size={18} />}
            onClick={() => navigate(`/project/${projectId}/preview`)}
            disabled={!hasAllDescriptions}
          >
            生成图片
          </Button>
        </div>
      </header>

      {/* 操作栏 */}
      <div className="bg-white border-b border-gray-200 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Button
              variant="primary"
              icon={<Sparkles size={18} />}
              onClick={handleGenerateAll}
            >
              批量生成描述
            </Button>
            <span className="text-sm text-gray-500">
              {currentProject.pages.filter((p) => p.description_content).length} /{' '}
              {currentProject.pages.length} 页已完成
            </span>
          </div>
        </div>
      </div>

      {/* 主内容区 */}
      <main className="flex-1 p-6 overflow-y-auto">
        <div className="max-w-7xl mx-auto">
          {currentProject.pages.length === 0 ? (
            <div className="text-center py-20">
              <div className="text-6xl mb-4">📝</div>
              <h3 className="text-xl font-semibold text-gray-700 mb-2">
                还没有页面
              </h3>
              <p className="text-gray-500 mb-6">
                请先返回大纲编辑页添加页面
              </p>
              <Button
                variant="primary"
                onClick={() => navigate(`/project/${projectId}/outline`)}
              >
                返回大纲编辑
              </Button>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {currentProject.pages.map((page, index) => (
                <DescriptionCard
                  key={page.id}
                  page={page}
                  index={index}
                  onUpdate={(data) => updatePageLocal(page.id, data)}
                  onRegenerate={() => handleRegeneratePage(page.id)}
                />
              ))}
            </div>
          )}
        </div>
      </main>
    </div>
  );
};


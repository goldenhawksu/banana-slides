import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  Home,
  ArrowLeft,
  Download,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  Sparkles,
} from 'lucide-react';
import { Button, Loading, Modal, Textarea } from '@/components/shared';
import { SlideCard } from '@/components/preview/SlideCard';
import { useProjectStore } from '@/store/useProjectStore';
import { getImageUrl } from '@/api/client';

export const SlidePreview: React.FC = () => {
  const navigate = useNavigate();
  const { projectId } = useParams<{ projectId: string }>();
  const {
    currentProject,
    syncProject,
    generateImages,
    generatePageImage,
    editPageImage,
    deletePageById,
    exportPPTX,
    exportPDF,
    isGlobalLoading,
    taskProgress,
  } = useProjectStore();

  const [selectedIndex, setSelectedIndex] = useState(0);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [editPrompt, setEditPrompt] = useState('');
  const [showExportMenu, setShowExportMenu] = useState(false);

  // 加载项目数据
  useEffect(() => {
    if (projectId && (!currentProject || currentProject.id !== projectId)) {
      // 直接使用 projectId 同步项目数据
      syncProject(projectId);
    }
  }, [projectId, currentProject, syncProject]);

  const handleGenerateAll = async () => {
    const hasImages = currentProject?.pages.some(
      (p) => p.generated_image_path
    );
    
    if (hasImages) {
      if (!confirm('部分页面已有图片，重新生成将覆盖，确定继续吗？')) {
        return;
      }
    }
    
    await generateImages();
  };

  const handleRegeneratePage = async () => {
    if (!currentProject) return;
    const page = currentProject.pages[selectedIndex];
    await generatePageImage(page.id);
  };

  const handleEditPage = () => {
    setEditPrompt('');
    setIsEditModalOpen(true);
  };

  const handleSubmitEdit = async () => {
    if (!currentProject || !editPrompt.trim()) return;
    
    const page = currentProject.pages[selectedIndex];
    await editPageImage(page.id, editPrompt);
    setIsEditModalOpen(false);
  };

  const handleExport = async (type: 'pptx' | 'pdf') => {
    setShowExportMenu(false);
    if (type === 'pptx') {
      await exportPPTX();
    } else {
      await exportPDF();
    }
  };

  if (!currentProject) {
    return <Loading fullscreen message="加载项目中..." />;
  }

  if (isGlobalLoading) {
    return (
      <Loading
        fullscreen
        message="生成图片中..."
        progress={taskProgress || undefined}
      />
    );
  }

  const selectedPage = currentProject.pages[selectedIndex];
  const imageUrl = selectedPage?.generated_image_path
    ? getImageUrl(selectedPage.generated_image_path)
    : '';

  const hasAllImages = currentProject.pages.every(
    (p) => p.generated_image_path
  );

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* 顶栏 */}
      <header className="h-16 bg-white shadow-sm border-b border-gray-200 flex items-center justify-between px-6">
        <div className="flex items-center gap-4">
          <Button
            variant="ghost"
            size="sm"
            icon={<Home size={18} />}
            onClick={() => navigate('/')}
          >
            主页
          </Button>
          <Button
            variant="ghost"
            size="sm"
            icon={<ArrowLeft size={18} />}
            onClick={() => navigate(`/project/${projectId}/detail`)}
          >
            返回
          </Button>
          <div className="flex items-center gap-2">
            <span className="text-2xl">🍌</span>
            <span className="text-xl font-bold">蕉幻</span>
          </div>
          <span className="text-gray-400">|</span>
          <span className="text-lg font-semibold">预览</span>
        </div>
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="sm"
            icon={<RefreshCw size={18} />}
            onClick={syncProject}
          >
            刷新
          </Button>
          <div className="relative">
            <Button
              variant="primary"
              size="sm"
              icon={<Download size={18} />}
              onClick={() => setShowExportMenu(!showExportMenu)}
              disabled={!hasAllImages}
            >
              导出
            </Button>
            {showExportMenu && (
              <div className="absolute right-0 mt-2 w-40 bg-white rounded-lg shadow-lg border border-gray-200 py-2 z-10">
                <button
                  onClick={() => handleExport('pptx')}
                  className="w-full px-4 py-2 text-left hover:bg-gray-50 transition-colors"
                >
                  导出为 PPTX
                </button>
                <button
                  onClick={() => handleExport('pdf')}
                  className="w-full px-4 py-2 text-left hover:bg-gray-50 transition-colors"
                >
                  导出为 PDF
                </button>
              </div>
            )}
          </div>
        </div>
      </header>

      {/* 主内容区 */}
      <div className="flex-1 flex">
        {/* 左侧：缩略图列表 */}
        <aside className="w-80 bg-white border-r border-gray-200 flex flex-col">
          <div className="p-4 border-b border-gray-200">
            <Button
              variant="primary"
              icon={<Sparkles size={18} />}
              onClick={handleGenerateAll}
              className="w-full"
            >
              批量生成图片 ({currentProject.pages.length})
            </Button>
          </div>
          
          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            {currentProject.pages.map((page, index) => (
              <SlideCard
                key={page.id}
                page={page}
                index={index}
                isSelected={selectedIndex === index}
                onClick={() => setSelectedIndex(index)}
                onEdit={() => {
                  setSelectedIndex(index);
                  handleEditPage();
                }}
                onDelete={() => deletePageById(page.id)}
              />
            ))}
          </div>
        </aside>

        {/* 右侧：大图预览 */}
        <main className="flex-1 flex flex-col bg-gradient-to-br from-banana-50 via-white to-gray-50">
          {currentProject.pages.length === 0 ? (
            <div className="flex-1 flex items-center justify-center">
              <div className="text-center">
                <div className="text-6xl mb-4">📊</div>
                <h3 className="text-xl font-semibold text-gray-700 mb-2">
                  还没有页面
                </h3>
                <p className="text-gray-500 mb-6">
                  请先返回编辑页面添加内容
                </p>
                <Button
                  variant="primary"
                  onClick={() => navigate(`/project/${projectId}/outline`)}
                >
                  返回编辑
                </Button>
              </div>
            </div>
          ) : (
            <>
              {/* 预览区 */}
              <div className="flex-1 flex items-center justify-center p-8">
                <div className="max-w-5xl w-full">
                  <div className="relative aspect-video bg-white rounded-lg shadow-xl overflow-hidden">
                    {selectedPage?.generated_image_path ? (
                      <img
                        src={imageUrl}
                        alt={`Slide ${selectedIndex + 1}`}
                        className="w-full h-full object-contain"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-gray-100">
                        <div className="text-center">
                          <div className="text-6xl mb-4">🖼️</div>
                          <p className="text-gray-500 mb-4">
                            {selectedPage?.status === 'GENERATING'
                              ? '正在生成中...'
                              : '尚未生成图片'}
                          </p>
                          {selectedPage?.status !== 'GENERATING' && (
                            <Button
                              variant="primary"
                              onClick={handleRegeneratePage}
                            >
                              生成此页
                            </Button>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* 控制栏 */}
              <div className="bg-white border-t border-gray-200 px-6 py-4">
                <div className="flex items-center justify-between max-w-5xl mx-auto">
                  {/* 导航 */}
                  <div className="flex items-center gap-2">
                    <Button
                      variant="ghost"
                      size="sm"
                      icon={<ChevronLeft size={18} />}
                      onClick={() => setSelectedIndex(Math.max(0, selectedIndex - 1))}
                      disabled={selectedIndex === 0}
                    >
                      上一页
                    </Button>
                    <span className="px-4 text-sm text-gray-600">
                      {selectedIndex + 1} / {currentProject.pages.length}
                    </span>
                    <Button
                      variant="ghost"
                      size="sm"
                      icon={<ChevronRight size={18} />}
                      onClick={() =>
                        setSelectedIndex(
                          Math.min(currentProject.pages.length - 1, selectedIndex + 1)
                        )
                      }
                      disabled={selectedIndex === currentProject.pages.length - 1}
                    >
                      下一页
                    </Button>
                  </div>

                  {/* 操作 */}
                  <div className="flex items-center gap-2">
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={handleEditPage}
                      disabled={!selectedPage?.generated_image_path}
                    >
                      编辑
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={handleRegeneratePage}
                    >
                      重新生成
                    </Button>
                  </div>
                </div>
              </div>
            </>
          )}
        </main>
      </div>

      {/* 编辑对话框 */}
      <Modal
        isOpen={isEditModalOpen}
        onClose={() => setIsEditModalOpen(false)}
        title="编辑页面"
        size="lg"
      >
        <div className="space-y-4">
          <div className="aspect-video bg-gray-100 rounded-lg overflow-hidden">
            {imageUrl && (
              <img
                src={imageUrl}
                alt="Current slide"
                className="w-full h-full object-contain"
              />
            )}
          </div>
          <Textarea
            label="输入修改指令"
            placeholder="例如：把背景改成蓝色、增大标题字号、更改文本框样式为虚线..."
            value={editPrompt}
            onChange={(e) => setEditPrompt(e.target.value)}
            rows={4}
          />
          <div className="flex justify-end gap-3">
            <Button variant="ghost" onClick={() => setIsEditModalOpen(false)}>
              取消
            </Button>
            <Button
              variant="primary"
              onClick={handleSubmitEdit}
              disabled={!editPrompt.trim()}
            >
              生成
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
};


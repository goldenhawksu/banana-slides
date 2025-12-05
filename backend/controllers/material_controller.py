"""
Material Controller - handles standalone material image generation
"""
from flask import Blueprint, request, current_app
from models import db, Project, Material
from utils import success_response, error_response, not_found, bad_request
from services import AIService, FileService
from pathlib import Path
from werkzeug.utils import secure_filename
from typing import Optional
import tempfile
import shutil
from PIL import Image
import time


material_bp = Blueprint('materials', __name__, url_prefix='/api/projects')
material_global_bp = Blueprint('materials_global', __name__, url_prefix='/api/materials')

ALLOWED_MATERIAL_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg'}


def _build_material_query(filter_project_id: str, validate_project: bool = True):
    """Build common material query with optional project validation."""
    query = Material.query

    if filter_project_id == 'all':
        return query, None
    if filter_project_id == 'none':
        return query.filter(Material.project_id.is_(None)), None

    if validate_project:
        project = Project.query.get(filter_project_id)
        if not project:
            return None, not_found('Project')

    return query.filter(Material.project_id == filter_project_id), None


def _resolve_target_project_id(raw_project_id: Optional[str], allow_none: bool = True):
    """
    Normalize project_id from request.
    Returns (project_id | None, error_response | None)
    """
    if allow_none and (raw_project_id is None or raw_project_id == 'none'):
        return None, None

    if raw_project_id == 'all':
        return None, bad_request("project_id cannot be 'all' when uploading materials")

    if raw_project_id:
        project = Project.query.get(raw_project_id)
        if not project:
            return None, not_found('Project')

    return raw_project_id, None


def _save_material_file(file, target_project_id: Optional[str]):
    """Shared logic for saving uploaded material files to disk and DB."""
    if not file or not file.filename:
        return None, bad_request("file is required")

    filename = secure_filename(file.filename)
    file_ext = Path(filename).suffix.lower()
    if file_ext not in ALLOWED_MATERIAL_EXTENSIONS:
        return None, bad_request(f"Unsupported file type. Allowed: {', '.join(sorted(ALLOWED_MATERIAL_EXTENSIONS))}")

    file_service = FileService(current_app.config['UPLOAD_FOLDER'])
    if target_project_id:
        materials_dir = file_service._get_materials_dir(target_project_id)
    else:
        materials_dir = file_service.upload_folder / "materials"
        materials_dir.mkdir(exist_ok=True, parents=True)

    timestamp = int(time.time() * 1000)
    base_name = Path(filename).stem
    unique_filename = f"{base_name}_{timestamp}{file_ext}"

    filepath = materials_dir / unique_filename
    file.save(str(filepath))

    relative_path = str(filepath.relative_to(file_service.upload_folder))
    if target_project_id:
        image_url = file_service.get_file_url(target_project_id, 'materials', unique_filename)
    else:
        image_url = f"/files/materials/{unique_filename}"

    material = Material(
        project_id=target_project_id,
        filename=unique_filename,
        relative_path=relative_path,
        url=image_url
    )

    try:
        db.session.add(material)
        db.session.commit()
        return material, None
    except Exception:
        db.session.rollback()
        raise


@material_bp.route('/<project_id>/materials/generate', methods=['POST'])
def generate_material_image(project_id):
    """
    POST /api/projects/{project_id}/materials/generate - Generate a standalone material image

    支持 multipart/form-data：
    - prompt: 文生图提示词（将被直接传给模型，不做任何修饰）
    - ref_image: 主参考图（可选）
    - extra_images: 额外参考图（可多文件，可选）
    """
    try:
        project = Project.query.get(project_id)
        if not project:
            return not_found('Project')

        # 解析请求数据（优先支持 multipart，用于文件上传）
        if request.is_json:
            data = request.get_json() or {}
            prompt = data.get('prompt', '').strip()
            ref_file = None
            extra_files = []
        else:
            data = request.form.to_dict()
            prompt = (data.get('prompt') or '').strip()
            ref_file = request.files.get('ref_image')
            # 支持多张额外参考图
            extra_files = request.files.getlist('extra_images') or []

        if not prompt:
            return bad_request("prompt is required")

        # 初始化服务
        ai_service = AIService(
            current_app.config['GOOGLE_API_KEY'],
            current_app.config['GOOGLE_API_BASE']
        )
        file_service = FileService(current_app.config['UPLOAD_FOLDER'])

        temp_dir = Path(tempfile.mkdtemp(dir=current_app.config['UPLOAD_FOLDER']))

        try:
            ref_path = None
            # 如果提供了主参考图，则保存到临时目录
            if ref_file and ref_file.filename:
                ref_filename = secure_filename(ref_file.filename or 'ref.png')
                ref_path = temp_dir / ref_filename
                ref_file.save(str(ref_path))

            # 保存额外参考图到临时目录
            additional_ref_images = []
            for extra in extra_files:
                if not extra or not extra.filename:
                    continue
                extra_filename = secure_filename(extra.filename)
                extra_path = temp_dir / extra_filename
                extra.save(str(extra_path))
                additional_ref_images.append(str(extra_path))

            # 使用用户原始 prompt 直接调用文生图模型（主参考图可选）
            image = ai_service.generate_image(
                prompt=prompt,
                ref_image_path=str(ref_path) if ref_path else None,
                aspect_ratio=current_app.config['DEFAULT_ASPECT_RATIO'],
                resolution=current_app.config['DEFAULT_RESOLUTION'],
                additional_ref_images=additional_ref_images or None,
            )

            if not image:
                return error_response('AI_SERVICE_ERROR', 'Failed to generate image', 503)

            # 保存生成的素材图片
            relative_path = file_service.save_material_image(image, project_id)
            # relative_path 形如 "<project_id>/materials/xxx.png"
            relative = Path(relative_path)
            # materials 目录下的文件名
            filename = relative.name

            # 构造前端可访问的 URL
            image_url = file_service.get_file_url(project_id, 'materials', filename)

            # 保存素材信息到数据库
            material = Material(
                project_id=project_id,
                filename=filename,
                relative_path=relative_path,
                url=image_url
            )
            db.session.add(material)
            
            # 不改变项目结构，仅更新时间以便前端刷新
            project.updated_at = project.updated_at  # 不强制变更，仅保持兼容
            db.session.commit()

            return success_response({
                "image_url": image_url,
                "relative_path": relative_path,
                "material_id": material.id,
            })
        finally:
            # 清理临时目录
            if temp_dir.exists():
                shutil.rmtree(temp_dir, ignore_errors=True)

    except Exception as e:
        db.session.rollback()
        return error_response('AI_SERVICE_ERROR', str(e), 503)


@material_bp.route('/<project_id>/materials', methods=['GET'])
def list_materials(project_id):
    """
    GET /api/projects/{project_id}/materials - List materials
    
    Query params:
        - project_id: Optional filter by project_id (can be 'all' to get all materials, 'none' to get materials without project)
    
    Returns:
        List of material images with filename, url, and metadata
    """
    try:
        # 支持查询参数来筛选项目
        filter_project_id = request.args.get('project_id', project_id)
        
        query, error = _build_material_query(filter_project_id, validate_project=True)
        if error:
            return error

        materials = query.order_by(Material.created_at.desc()).all()
        
        # 转换为字典格式
        materials_list = [material.to_dict() for material in materials]
        
        return success_response({
            "materials": materials_list,
            "count": len(materials_list)
        })
    
    except Exception as e:
        return error_response('SERVER_ERROR', str(e), 500)


@material_bp.route('/<project_id>/materials/upload', methods=['POST'])
def upload_material(project_id):
    """
    POST /api/projects/{project_id}/materials/upload - Upload a material image
    
    支持 multipart/form-data：
    - file: 图片文件（必需）
    - project_id: 可选的查询参数，如果不提供则使用路径中的 project_id，如果为 'none' 则不关联项目
    
    Returns:
        Material info with filename, url, and metadata
    """
    try:
        # 支持通过查询参数指定 project_id，如果为 'none' 则不关联项目
        raw_project_id = request.args.get('project_id', project_id)
        target_project_id, error = _resolve_target_project_id(raw_project_id)
        if error:
            return error

        file = request.files.get('file')
        material, error = _save_material_file(file, target_project_id)
        if error:
            return error

        return success_response(material.to_dict(), status_code=201)
    
    except Exception as e:
        db.session.rollback()
        return error_response('SERVER_ERROR', str(e), 500)


@material_global_bp.route('', methods=['GET'])
def list_all_materials():
    """
    GET /api/materials - List all materials (global, not bound to a project)
    
    Query params:
        - project_id: Optional filter by project_id (can be 'all' to get all materials, 'none' to get materials without project)
    
    Returns:
        List of material images with filename, url, and metadata
    """
    try:
        # 支持查询参数来筛选项目
        filter_project_id = request.args.get('project_id', 'all')
        
        query, error = _build_material_query(filter_project_id, validate_project=True)
        if error:
            return error
        
        materials = query.order_by(Material.created_at.desc()).all()
        
        # 转换为字典格式
        materials_list = [material.to_dict() for material in materials]
        
        return success_response({
            "materials": materials_list,
            "count": len(materials_list)
        })
    
    except Exception as e:
        return error_response('SERVER_ERROR', str(e), 500)


@material_global_bp.route('/upload', methods=['POST'])
def upload_material_global():
    """
    POST /api/materials/upload - Upload a material image (global, not bound to a project)
    
    支持 multipart/form-data：
    - file: 图片文件（必需）
    - project_id: 可选的查询参数，如果提供则关联到项目，如果不提供或为 'none' 则不关联项目
    
    Returns:
        Material info with filename, url, and metadata
    """
    try:
        # 支持通过查询参数指定 project_id，如果为 'none' 或不提供则不关联项目
        raw_project_id = request.args.get('project_id')
        target_project_id, error = _resolve_target_project_id(raw_project_id)
        if error:
            return error

        file = request.files.get('file')
        material, error = _save_material_file(file, target_project_id)
        if error:
            return error

        return success_response(material.to_dict(), status_code=201)
    
    except Exception as e:
        db.session.rollback()
        return error_response('SERVER_ERROR', str(e), 500)


@material_global_bp.route('/<material_id>', methods=['DELETE'])
def delete_material(material_id):
    """
    DELETE /api/materials/{material_id} - Delete a material and its file
    """
    try:
        material = Material.query.get(material_id)
        if not material:
            return not_found('Material')

        file_service = FileService(current_app.config['UPLOAD_FOLDER'])
        material_path = Path(file_service.get_absolute_path(material.relative_path))

        # 删除文件（若存在）
        if material_path.exists():
            material_path.unlink(missing_ok=True)

        db.session.delete(material)
        db.session.commit()

        return success_response({"id": material_id})
    except Exception as e:
        db.session.rollback()
        return error_response('SERVER_ERROR', str(e), 500)


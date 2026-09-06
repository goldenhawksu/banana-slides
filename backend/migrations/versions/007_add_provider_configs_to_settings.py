"""add provider_configs to settings table

Revision ID: 007_provider_configs
Revises: 38292967f3ca
Create Date: 2026-09-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = '007_provider_configs'
down_revision = '38292967f3ca'
branch_labels = None
depends_on = None


def _column_exists(table_name: str, column_name: str) -> bool:
    bind = op.get_bind()
    inspector = inspect(bind)
    columns = [c['name'] for c in inspector.get_columns(table_name)]
    return column_name in columns


def upgrade() -> None:
    if not _column_exists('settings', 'openai_config'):
        op.add_column('settings', sa.Column('openai_config', sa.Text(), nullable=True))
    if not _column_exists('settings', 'gemini_config'):
        op.add_column('settings', sa.Column('gemini_config', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('settings', 'openai_config')
    op.drop_column('settings', 'gemini_config')

"""added group links table

Revision ID: 8a878a9ab082
Revises: 1f3e5f8f6d2a
Create Date: 2026-02-12 13:28:25.123901

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '8a878a9ab082'
down_revision: Union[str, Sequence[str], None] = '1f3e5f8f6d2a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create the group_links table
    op.create_table(
        'group_links',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('chit_group_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('platform', sa.String(), nullable=True),
        sa.Column('link_url', sa.String(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    
    # 2. Add Foreign Key Constraint
    op.create_foreign_key(
        'fk_group_links_chit_group', 
        'group_links', 'chit_groups', 
        ['chit_group_id'], ['id']
    )

def downgrade() -> None:
    # Drop the table if we roll back
    op.drop_table('group_links')

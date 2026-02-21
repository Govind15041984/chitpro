"""add chit_payment_audit table

Revision ID: c5750dd93e9f
Revises: 832e5bfabf4b
Create Date: 2026-02-06 09:45:29.876331

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import uuid


# revision identifiers, used by Alembic.
revision: str = 'c5750dd93e9f'
down_revision: Union[str, Sequence[str], None] = '832e5bfabf4b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.create_table(
        "chit_payment_audit",
        sa.Column("id", sa.UUID(), primary_key=True, default=uuid.uuid4),
        sa.Column("ledger_id", sa.UUID(), nullable=False),
        sa.Column("chit_group_id", sa.UUID(), nullable=False),
        sa.Column("member_id", sa.UUID(), nullable=False),
        sa.Column("action", sa.String(50), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("performed_by", sa.UUID(), nullable=True),
        sa.Column("performed_at", sa.DateTime(), nullable=False),
        sa.Column("remarks", sa.Text(), nullable=True),
    )


def downgrade():
    op.drop_table("chit_payment_audit")

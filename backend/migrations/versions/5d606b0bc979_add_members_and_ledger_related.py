"""add members and ledger related

Revision ID: 5d606b0bc979
Revises: f85503c73839
Create Date: 2026-02-03 13:31:56.409699
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '5d606b0bc979'
down_revision: Union[str, Sequence[str], None] = 'f85503c73839'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ⚠️ Commented for safety — enable later if needed
    # op.drop_index(
    #     op.f('one_open_auction_per_chit'),
    #     table_name='auction_rounds',
    #     postgresql_where="((status)::text = 'OPEN'::text)"
    # )

    op.alter_column(
        'chit_groups',
        'current_month_no',
        existing_type=sa.INTEGER(),
        nullable=False
    )

    # 🔥 joined_month (safe default)
    op.add_column(
        'chit_members',
        sa.Column(
            'joined_month',
            sa.Integer(),
            nullable=False,
            server_default="1"
        )
    )

    # 🔥 payment tracking (STEP2D)
    op.add_column(
        'member_ledger',
        sa.Column(
            'payment_status',
            sa.String(length=20),
            nullable=False,
            server_default="PENDING"
        )
    )

    op.add_column(
        'member_ledger',
        sa.Column(
            'paid_at',
            sa.DateTime(),
            nullable=True
        )
    )


def downgrade() -> None:
    op.drop_column('member_ledger', 'paid_at')
    op.drop_column('member_ledger', 'payment_status')
    op.drop_column('chit_members', 'joined_month')

    op.alter_column(
        'chit_groups',
        'current_month_no',
        existing_type=sa.INTEGER(),
        nullable=True
    )

    # Optional — only if index existed before
    # op.create_index(
    #     op.f('one_open_auction_per_chit'),
    #     'auction_rounds',
    #     ['chit_group_id'],
    #     unique=True,
    #     postgresql_where="((status)::text = 'OPEN'::text)"
    # )

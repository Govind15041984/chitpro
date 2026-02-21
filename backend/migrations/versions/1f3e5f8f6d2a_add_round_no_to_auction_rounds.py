"""add round_no to auction_rounds

Revision ID: 1f3e5f8f6d2a
Revises: c5750dd93e9f
Create Date: 2026-02-07 13:26:45.504799
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '1f3e5f8f6d2a'
down_revision: Union[str, Sequence[str], None] = 'c5750dd93e9f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # 1️⃣ Add column as nullable first (to avoid failing on existing rows)
    op.add_column('auction_rounds', sa.Column('round_no', sa.Integer(), nullable=True))

    # 2️⃣ Backfill existing rows with round_no = 1
    op.execute("UPDATE auction_rounds SET round_no = 1 WHERE round_no IS NULL")

    # 3️⃣ Alter column to NOT NULL
    op.alter_column('auction_rounds', 'round_no', nullable=False)

    # (Optional but recommended) Add unique constraint later if you want
    # op.create_unique_constraint(
    #     "uq_auction_round",
    #     "auction_rounds",
    #     ["chit_group_id", "month_no", "round_no"]
    # )


def downgrade() -> None:
    """Downgrade schema."""
    # Remove round_no column
    op.drop_column('auction_rounds', 'round_no')

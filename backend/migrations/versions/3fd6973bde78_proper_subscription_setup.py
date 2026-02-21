"""proper_subscription_setup

Revision ID: 3fd6973bde78
Revises: 8a878a9ab082
Create Date: 2026-02-15 12:46:41.731455

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '3fd6973bde78'
down_revision: Union[str, Sequence[str], None] = '8a878a9ab082'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # 1. Create the Master Plan Table
    op.create_table('subscription_plans',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('slab_code', sa.String(length=50), nullable=False),
        sa.Column('price_rupees', sa.Integer(), nullable=False),
        sa.Column('group_limit', sa.Integer(), nullable=False),
        sa.Column('member_limit', sa.Integer(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('slab_code')
    )

    # 2. SEED DATA: Insert plans before linking Foreign Keys
    # This prevents the "Key (slab_code)=(FREE) is not present" error
    op.execute(
        "INSERT INTO subscription_plans (id, slab_code, price_rupees, group_limit, member_limit, is_active, created_at) "
        "VALUES ('550e8400-e29b-41d4-a716-446655440000', 'FREE', 0, 1, 30, true, now())"
    )
    op.execute(
        "INSERT INTO subscription_plans (id, slab_code, price_rupees, group_limit, member_limit, is_active, created_at) "
        "VALUES (gen_random_uuid(), 'BASIC_199', 1, 3, 100, true, now())"
    )
    op.execute(
        "INSERT INTO subscription_plans (id, slab_code, price_rupees, group_limit, member_limit, is_active, created_at) "
        "VALUES (gen_random_uuid(), 'STANDARD_499', 1, 10, 999, true, now())"
    )
    op.execute(
        "INSERT INTO subscription_plans (id, slab_code, price_rupees, group_limit, member_limit, is_active, created_at) "
        "VALUES (gen_random_uuid(), 'PREMIUM_1499', 1, 999, 999, true, now())"
    )

    # 3. Update Audit Table (Housekeeping)
    op.alter_column('chit_payment_audit', 'action',
               existing_type=sa.VARCHAR(length=50),
               type_=sa.String(length=20),
               existing_nullable=False)
    op.alter_column('chit_payment_audit', 'performed_at',
               existing_type=postgresql.TIMESTAMP(),
               nullable=True)
    op.alter_column('chit_payment_audit', 'remarks',
               existing_type=sa.TEXT(),
               type_=sa.String(length=255),
               existing_nullable=True)
    op.create_foreign_key(None, 'chit_payment_audit', 'chit_groups', ['chit_group_id'], ['id'])
    op.create_foreign_key(None, 'chit_payment_audit', 'member_ledger', ['ledger_id'], ['id'])
    op.create_foreign_key(None, 'chit_payment_audit', 'chit_members', ['member_id'], ['id'])

    # 4. Update Subscriptions Table
    op.add_column('subscriptions', sa.Column('razorpay_order_id', sa.String(length=100), nullable=True))
    op.add_column('subscriptions', sa.Column('razorpay_payment_id', sa.String(length=100), nullable=True))
    op.alter_column('subscriptions', 'slab_code',
               existing_type=sa.VARCHAR(length=20),
               type_=sa.String(length=50),
               existing_nullable=False)
    
    # Now that 'FREE' exists in subscription_plans, this will succeed
    op.create_foreign_key(None, 'subscriptions', 'subscription_plans', ['slab_code'], ['slab_code'])
    
    op.drop_column('subscriptions', 'razorpay_subscription_id')
    op.drop_column('subscriptions', 'amount')


def downgrade() -> None:
    """Downgrade schema."""
    op.add_column('subscriptions', sa.Column('amount', sa.INTEGER(), autoincrement=False, nullable=False))
    op.add_column('subscriptions', sa.Column('razorpay_subscription_id', sa.VARCHAR(length=100), autoincrement=False, nullable=True))
    op.drop_constraint(None, 'subscriptions', type_='foreignkey')
    op.alter_column('subscriptions', 'slab_code',
               existing_type=sa.String(length=50),
               type_=sa.VARCHAR(length=20),
               existing_nullable=False)
    op.drop_column('subscriptions', 'razorpay_payment_id')
    op.drop_column('subscriptions', 'razorpay_order_id')
    op.drop_constraint(None, 'chit_payment_audit', type_='foreignkey')
    op.drop_constraint(None, 'chit_payment_audit', type_='foreignkey')
    op.drop_constraint(None, 'chit_payment_audit', type_='foreignkey')
    op.alter_column('chit_payment_audit', 'remarks',
               existing_type=sa.String(length=255),
               type_=sa.TEXT(),
               existing_nullable=True)
    op.alter_column('chit_payment_audit', 'performed_at',
               existing_type=postgresql.TIMESTAMP(),
               nullable=False)
    op.alter_column('chit_payment_audit', 'action',
               existing_type=sa.String(length=20),
               type_=sa.VARCHAR(length=50),
               existing_nullable=False)
    op.drop_table('subscription_plans')
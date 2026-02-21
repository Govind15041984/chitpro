# app/core/chit_state_engine.py

class ChitStateError(Exception):
    pass


ALLOWED_TRANSITIONS = { 
    "DRAFT": ["CONFIGURED"],
    "CONFIGURED": ["ACTIVE"],
    "ACTIVE": ["RUNNING"],
    "RUNNING": ["CLOSED"],
    "CLOSED": []
}


def assert_transition(current: str, target: str):
    if target not in ALLOWED_TRANSITIONS.get(current, []):
        raise ChitStateError(f"Invalid transition: {current} -> {target}")


def move_state(chit_group, target_state: str):
    """
    Central state transition function.
    All state changes MUST go through this.
    """
    import os
    print("🔥 USING chit_state_engine FROM:", os.path.abspath(__file__))
    current_state = chit_group.lifecycle_status

    # 1. Validate flow
    assert_transition(current_state, target_state)

    # 2. Apply transition
    chit_group.lifecycle_status = target_state
    return chit_group


# Optional: semantic helpers (readable, safe, future-proof)

def mark_configured(chit_group):
    return move_state(chit_group, "CONFIGURED")


def mark_active(chit_group):
    return move_state(chit_group, "ACTIVE")


def mark_running(chit_group):
    chit_group = move_state(chit_group, "RUNNING")

    # 🔥 Ensure first month is set
    #if chit_group.current_month_no is None or chit_group.current_month_no <= 0:
    #    chit_group.current_month_no = 1

    return chit_group



def mark_closed(chit_group):
    return move_state(chit_group, "CLOSED")

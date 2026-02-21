from app.core.chit_state_engine import assert_transition
from app.models.chit_group_model import ChitGroup

def move_to_configured(db, chit_group_id, settings):
    chit = db.query(ChitGroup).get(chit_group_id)
    assert_transition(chit.lifecycle_status, "CONFIGURED")

    chit.settings = settings
    chit.lifecycle_status = "CONFIGURED"
    db.commit()
    return chit


def move_to_active(db, chit_group_id):
    chit = db.query(ChitGroup).get(chit_group_id)
    assert_transition(chit.lifecycle_status, "ACTIVE")

    chit.lifecycle_status = "ACTIVE"
    db.commit()
    return chit


def move_to_running(db, chit_group_id):
    chit = db.query(ChitGroup).get(chit_group_id)
    assert_transition(chit.lifecycle_status, "RUNNING")

    chit.lifecycle_status = "RUNNING"
    db.commit()
    return chit


def move_to_closed(db, chit_group_id):
    chit = db.query(ChitGroup).get(chit_group_id)
    assert_transition(chit.lifecycle_status, "CLOSED")

    chit.lifecycle_status = "CLOSED"
    db.commit()
    return chit

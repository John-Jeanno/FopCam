import re


_PRIVATE_ROOM_PATTERN = re.compile(r'^private_([1-9]\d*)_([1-9]\d*)$')


def private_room_participant_ids(room):
    if not isinstance(room, str):
        return None

    match = _PRIVATE_ROOM_PATTERN.fullmatch(room)
    if match is None:
        return None

    first_id, second_id = (int(value) for value in match.groups())
    if first_id >= second_id:
        return None
    return first_id, second_id

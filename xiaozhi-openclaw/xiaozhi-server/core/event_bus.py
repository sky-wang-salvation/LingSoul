"""
Simple in-process event bus for pushing session events to dashboard WebSocket clients.
"""
import asyncio
import json
from typing import Any

_subscribers: list[asyncio.Queue] = []
_history: list[dict] = []
_MAX_HISTORY = 200


def subscribe() -> asyncio.Queue:
    q: asyncio.Queue = asyncio.Queue(maxsize=64)
    _subscribers.append(q)
    return q


def unsubscribe(q: asyncio.Queue) -> None:
    try:
        _subscribers.remove(q)
    except ValueError:
        pass


def emit(event_type: str, **kwargs: Any) -> None:
    """Emit an event to all dashboard subscribers. Call from async context."""
    import time
    event = {"type": event_type, "ts": round(time.time() * 1000), **kwargs}
    _history.append(event)
    if len(_history) > _MAX_HISTORY:
        _history.pop(0)
    dead = []
    for q in _subscribers:
        try:
            q.put_nowait(event)
        except asyncio.QueueFull:
            dead.append(q)
    for q in dead:
        unsubscribe(q)


def get_history() -> list[dict]:
    return list(_history)

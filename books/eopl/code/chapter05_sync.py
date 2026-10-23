#!/usr/bin/env python3
"""Executable scheduler models for 5.56/5.57. Commands are yielded snapshots,
not a second parser for THREADS. Messages contain JSON-like immutable data.
"""
from collections import deque
from copy import deepcopy
from dataclasses import dataclass, field
import json

@dataclass
class Semaphore:
    count: int
    waiting: deque = field(default_factory=deque)

@dataclass
class Condition:
    waiting: deque = field(default_factory=deque)

@dataclass
class Barrier:
    parties: int
    generation: int = 0
    waiting: list = field(default_factory=list)

@dataclass
class Task:
    ident: int
    continuation: object
    store: dict = field(default_factory=dict)
    mailbox: deque = field(default_factory=deque)
    pending: object = None
    status: str = "new"

class Scheduler:
    def __init__(self):
        self.tasks, self.ready, self.output = {}, deque(), []

    def add(self, program):
        ident = len(self.tasks)
        task = Task(ident, None)
        task.continuation = program(task)  # task.store is private to this thread
        self.tasks[ident] = task
        self.wake(task)
        return ident

    def wake(self, task, value=None):
        assert task.status != "ready"
        task.pending, task.status = value, "ready"
        self.ready.append(task)
        assert len({t.ident for t in self.ready}) == len(self.ready)

    def up(self, sem):
        if sem.waiting:
            self.wake(sem.waiting.popleft())  # direct handoff, no spare permit
        else:
            sem.count += 1

    def down(self, sem, task):
        if sem.count:
            sem.count -= 1
            self.wake(task)
        else:
            task.status = "semaphore"
            sem.waiting.append(task)

    def run(self, fuel=10000):
        steps = 0
        while self.ready:
            steps += 1
            if steps > fuel:
                raise RuntimeError("fuel exhausted")
            task = self.ready.popleft()
            task.status = "running"
            try:
                action = task.continuation.send(task.pending)
            except StopIteration:
                task.status = "done"
                continue
            op, *args = action
            if op == "down":
                self.down(args[0], task)
            elif op == "up":
                self.up(args[0]); self.wake(task)
            elif op == "condition-wait":
                condition, lock = args
                condition.waiting.append(task)
                task.status = "condition"
                self.up(lock)  # enqueue+release is one atomic scheduler operation
            elif op == "condition-signal":
                if args[0].waiting:
                    self.wake(args[0].waiting.popleft())
                self.wake(task)
            elif op == "barrier":
                barrier = args[0]
                barrier.waiting.append(task); task.status = "barrier"
                if len(barrier.waiting) == barrier.parties:
                    waiting, barrier.waiting = barrier.waiting, []
                    barrier.generation += 1
                    for waiter in waiting:
                        self.wake(waiter, barrier.generation)
            elif op == "send":
                dest, value = args
                receiver = self.tasks[dest]
                # This model restricts messages to JSON data, never references/closures.
                copied = json.loads(json.dumps(value))
                if receiver.status == "receive":
                    self.wake(receiver, copied)
                else:
                    receiver.mailbox.append(copied)
                self.wake(task)
            elif op == "receive":
                if task.mailbox:
                    self.wake(task, task.mailbox.popleft())
                else:
                    task.status = "receive"
            elif op == "print":
                self.output.append(args[0]); self.wake(task)
            else:
                raise ValueError(op)
        return {t.ident: t.status for t in self.tasks.values()}

# BEGIN synchronization-examples
def examples():
    # Counting semaphore: no more than two workers enter at once.
    scheduler, sem, active = Scheduler(), Semaphore(2), {"n": 0, "max": 0}
    def worker(task):
        yield "down", sem
        active["n"] += 1; active["max"] = max(active["max"], active["n"])
        yield "print", task.ident
        active["n"] -= 1
        yield "up", sem
    for _ in range(5): scheduler.add(worker)
    assert set(scheduler.run().values()) == {"done"} and active["max"] == 2
    # Mesa-style condition: signal makes ready; consumer reacquires the lock.
    scheduler, lock, cond, buffer = Scheduler(), Semaphore(1), Condition(), []
    def consumer(task):
        yield "down", lock
        while not buffer:
            yield "condition-wait", cond, lock
            yield "down", lock
        task.store["answer"] = buffer.pop(0)
        yield "up", lock
    def producer(task):
        yield "down", lock
        buffer.append(44)
        yield "condition-signal", cond
        yield "up", lock
    cid = scheduler.add(consumer); scheduler.add(producer)
    assert set(scheduler.run().values()) == {"done"}
    assert scheduler.tasks[cid].store["answer"] == 44
    # Reusable barrier: generation cannot mix participants across rounds.
    scheduler, barrier = Scheduler(), Barrier(3)
    def participant(task):
        for round_number in (1, 2):
            generation = yield "barrier", barrier
            assert generation == round_number
            yield "print", [task.ident, generation]
    for _ in range(3): scheduler.add(participant)
    assert set(scheduler.run().values()) == {"done"} and barrier.generation == 2
    # Private-store actors: one owner applies three increment messages, no mutex.
    scheduler = Scheduler()
    def owner(task):
        task.store["x"] = 0
        for _ in range(3):
            amount = yield "receive",
            task.store["x"] += amount
        yield "print", task.store["x"]
    owner_id = scheduler.add(owner)
    def sender(task):
        task.store["x"] = 100  # same name, different private store
        yield "send", owner_id, 1
    for _ in range(3): scheduler.add(sender)
    assert set(scheduler.run().values()) == {"done"}
    assert scheduler.output == [3]
    assert [t.store["x"] for t in scheduler.tasks.values()] == [3, 100, 100, 100]
    return {"counting_semaphore_peak": active["max"], "condition_value": 44,
            "barrier_generations": barrier.generation, "private_counter": scheduler.output[0]}
# END synchronization-examples
if __name__ == "__main__":
    print(json.dumps({"status": "passed", "models": examples()}, ensure_ascii=False))

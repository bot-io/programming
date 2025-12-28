"""
Conflict Prevention System for AI Agent Teams.
Prevents agents from interfering with each other's work through:
- Resource locking
- Workspace isolation
- Change validation
- Atomic operations
"""

from enum import Enum
from dataclasses import dataclass, field
from typing import Dict, Set, List, Optional, Tuple
from datetime import datetime, timedelta
from collections import defaultdict
import threading
import hashlib
import json


class LockType(Enum):
    """Types of resource locks"""
    EXCLUSIVE = "exclusive"  # Only one agent can access
    SHARED_READ = "shared_read"  # Multiple agents can read
    SHARED_WRITE = "shared_write"  # Multiple agents can write (with coordination)


class ResourceLock:
    """Represents a lock on a resource (file, directory, etc.)"""
    
    def __init__(self, resource_path: str, agent_id: str, lock_type: LockType, timeout_minutes: int = 60):
        self.resource_path = resource_path
        self.agent_id = agent_id
        self.lock_type = lock_type
        self.acquired_at = datetime.now()
        self.timeout = timedelta(minutes=timeout_minutes)
        self.expires_at = self.acquired_at + self.timeout
    
    def is_expired(self) -> bool:
        """Check if lock has expired"""
        return datetime.now() > self.expires_at
    
    def extend(self, minutes: int = 30):
        """Extend lock timeout"""
        self.timeout = timedelta(minutes=minutes)
        self.expires_at = datetime.now() + self.timeout
    
    def to_dict(self):
        return {
            "resource_path": self.resource_path,
            "agent_id": self.agent_id,
            "lock_type": self.lock_type.value,
            "acquired_at": self.acquired_at.isoformat(),
            "expires_at": self.expires_at.isoformat()
        }


@dataclass
class ChangeSet:
    """Represents a set of changes made by an agent"""
    agent_id: str
    task_id: str
    files_modified: List[str] = field(default_factory=list)
    files_created: List[str] = field(default_factory=list)
    files_deleted: List[str] = field(default_factory=list)
    checksums: Dict[str, str] = field(default_factory=dict)  # file -> checksum
    timestamp: datetime = field(default_factory=datetime.now)
    description: str = ""
    
    def to_dict(self):
        return {
            "agent_id": self.agent_id,
            "task_id": self.task_id,
            "files_modified": self.files_modified,
            "files_created": self.files_created,
            "files_deleted": self.files_deleted,
            "checksums": self.checksums,
            "timestamp": self.timestamp.isoformat(),
            "description": self.description
        }


class ResourceLockManager:
    """
    Manages resource locks to prevent concurrent modifications.
    Thread-safe resource locking system.
    """
    
    def __init__(self):
        self.locks: Dict[str, ResourceLock] = {}  # resource_path -> lock
        self.agent_locks: Dict[str, Set[str]] = defaultdict(set)  # agent_id -> set of resources
        self.lock = threading.Lock()  # For thread safety
    
    def acquire_lock(
        self,
        resource_path: str,
        agent_id: str,
        lock_type: LockType = LockType.EXCLUSIVE,
        timeout_minutes: int = 60
    ) -> bool:
        """
        Acquire a lock on a resource.
        Returns True if lock acquired, False if resource is already locked.
        """
        with self.lock:
            # Clean up expired locks
            self._cleanup_expired_locks()
            
            # Check if resource is already locked
            if resource_path in self.locks:
                existing_lock = self.locks[resource_path]
                
                # Allow if same agent and extending lock
                if existing_lock.agent_id == agent_id:
                    existing_lock.extend(timeout_minutes)
                    return True
                
                # Check lock compatibility
                if lock_type == LockType.SHARED_READ and existing_lock.lock_type == LockType.SHARED_READ:
                    # Multiple shared read locks allowed
                    pass
                else:
                    # Resource is locked by another agent
                    return False
            
            # Acquire new lock
            new_lock = ResourceLock(resource_path, agent_id, lock_type, timeout_minutes)
            self.locks[resource_path] = new_lock
            self.agent_locks[agent_id].add(resource_path)
            return True
    
    def release_lock(self, resource_path: str, agent_id: str) -> bool:
        """Release a lock on a resource"""
        with self.lock:
            if resource_path not in self.locks:
                return False
            
            lock = self.locks[resource_path]
            if lock.agent_id != agent_id:
                return False  # Agent doesn't own this lock
            
            del self.locks[resource_path]
            self.agent_locks[agent_id].discard(resource_path)
            return True
    
    def release_all_agent_locks(self, agent_id: str):
        """Release all locks held by an agent"""
        with self.lock:
            resources = list(self.agent_locks[agent_id])
            for resource_path in resources:
                if resource_path in self.locks:
                    del self.locks[resource_path]
            self.agent_locks[agent_id].clear()
    
    def is_locked(self, resource_path: str) -> bool:
        """Check if a resource is currently locked"""
        with self.lock:
            self._cleanup_expired_locks()
            return resource_path in self.locks
    
    def get_lock_owner(self, resource_path: str) -> Optional[str]:
        """Get the agent ID that owns the lock on a resource"""
        with self.lock:
            if resource_path in self.locks:
                return self.locks[resource_path].agent_id
            return None
    
    def get_agent_locks(self, agent_id: str) -> List[str]:
        """Get all resources locked by an agent"""
        with self.lock:
            return list(self.agent_locks[agent_id])
    
    def _cleanup_expired_locks(self):
        """Remove expired locks"""
        expired = [
            path for path, lock in self.locks.items()
            if lock.is_expired()
        ]
        for path in expired:
            agent_id = self.locks[path].agent_id
            del self.locks[path]
            self.agent_locks[agent_id].discard(path)
    
    def get_locks_status(self) -> Dict:
        """Get status of all locks"""
        with self.lock:
            self._cleanup_expired_locks()
            return {
                "total_locks": len(self.locks),
                "locks": {
                    path: lock.to_dict()
                    for path, lock in self.locks.items()
                },
                "agent_locks": {
                    agent_id: list(resources)
                    for agent_id, resources in self.agent_locks.items()
                }
            }


class ConflictDetector:
    """
    Detects conflicts between changes made by different agents.
    """
    
    def __init__(self):
        self.change_history: List[ChangeSet] = []
        self.integrated_changes: Set[str] = set()  # task_ids that have been integrated
    
    def register_changes(self, change_set: ChangeSet):
        """Register changes made by an agent"""
        self.change_history.append(change_set)
    
    def detect_conflicts(
        self,
        new_change_set: ChangeSet,
        check_integrated: bool = True
    ) -> List[str]:
        """
        Detect conflicts between new changes and existing changes.
        Returns list of conflicting task IDs or file paths.
        
        Note: When check_integrated=False, we allow updates to files from completed tasks.
        """
        conflicts = []
        
        # Check against integrated changes (only if check_integrated is True)
        # When False, we allow updates to files from completed tasks
        if check_integrated:
            for change_set in self.change_history:
                if change_set.task_id in self.integrated_changes:
                    # Check for file conflicts
                    new_files = set(new_change_set.files_modified + new_change_set.files_created)
                    existing_files = set(change_set.files_modified + change_set.files_created)
                    
                    conflicting_files = new_files.intersection(existing_files)
                    if conflicting_files:
                        conflicts.append(f"Conflict with integrated task {change_set.task_id}: files {conflicting_files}")
        
        # Check against pending changes (not yet integrated) - always check these
        for change_set in self.change_history:
            if (change_set.task_id not in self.integrated_changes and
                change_set.task_id != new_change_set.task_id):
                
                new_files = set(new_change_set.files_modified + new_change_set.files_created)
                existing_files = set(change_set.files_modified + change_set.files_created)
                
                conflicting_files = new_files.intersection(existing_files)
                if conflicting_files:
                    conflicts.append(f"Potential conflict with pending task {change_set.task_id}: files {conflicting_files}")
        
        return conflicts
    
    def mark_integrated(self, task_id: str):
        """Mark a task's changes as integrated"""
        self.integrated_changes.add(task_id)
    
    def validate_integration(
        self,
        change_set: ChangeSet,
        validation_function=None,
        allow_completed_updates: bool = False
    ) -> Tuple[bool, List[str]]:
        """
        Validate that changes can be safely integrated.
        Returns (is_valid, list_of_issues)
        """
        issues = []
        
        # Check for conflicts
        conflicts = self.detect_conflicts(change_set, check_integrated=not allow_completed_updates)
        if conflicts:
            issues.extend(conflicts)
        
        # Run custom validation if provided
        if validation_function:
            try:
                validation_result = validation_function(change_set)
                if not validation_result:
                    issues.append("Custom validation failed")
            except Exception as e:
                issues.append(f"Validation error: {str(e)}")
        
        return len(issues) == 0, issues


class WorkspaceManager:
    """
    Manages isolated workspaces for agents to prevent conflicts.
    Each agent works in its own workspace/branch.
    """
    
    def __init__(self, base_workspace: str = "workspaces"):
        self.base_workspace = base_workspace
        self.agent_workspaces: Dict[str, str] = {}  # agent_id -> workspace_path
    
    def create_workspace(self, agent_id: str, task_id: str) -> str:
        """Create an isolated workspace for an agent"""
        workspace_path = f"{self.base_workspace}/{agent_id}/{task_id}"
        self.agent_workspaces[agent_id] = workspace_path
        return workspace_path
    
    def get_workspace(self, agent_id: str) -> Optional[str]:
        """Get workspace path for an agent"""
        return self.agent_workspaces.get(agent_id)
    
    def cleanup_workspace(self, agent_id: str, task_id: str):
        """Clean up workspace after task completion"""
        if agent_id in self.agent_workspaces:
            # In real implementation, would delete workspace directory
            # For now, just remove from tracking
            pass


class AtomicOperation:
    """
    Represents an atomic operation that can be committed or rolled back.
    """
    
    def __init__(self, operation_id: str, agent_id: str, description: str):
        self.operation_id = operation_id
        self.agent_id = agent_id
        self.description = description
        self.created_at = datetime.now()
        self.changes: List[Dict] = []  # List of reversible changes
        self.committed = False
        self.rolled_back = False
    
    def add_change(self, change_type: str, resource: str, old_value: Optional[str] = None, new_value: Optional[str] = None):
        """Add a change to the operation (stored for potential rollback)"""
        self.changes.append({
            "type": change_type,  # "create", "modify", "delete"
            "resource": resource,
            "old_value": old_value,
            "new_value": new_value,
            "timestamp": datetime.now().isoformat()
        })
    
    def commit(self):
        """Mark operation as committed"""
        self.committed = True
    
    def rollback(self) -> List[Dict]:
        """Rollback the operation, returns list of changes to revert"""
        if self.committed:
            raise ValueError("Cannot rollback committed operation")
        
        self.rolled_back = True
        return self.changes


class ConflictPreventionSystem:
    """
    Main system for preventing conflicts between agents.
    Combines locking, workspace isolation, and conflict detection.
    """
    
    def __init__(self):
        self.lock_manager = ResourceLockManager()
        self.conflict_detector = ConflictDetector()
        self.workspace_manager = WorkspaceManager()
        self.atomic_operations: Dict[str, AtomicOperation] = {}  # operation_id -> operation
    
    def request_resource_access(
        self,
        resource_path: str,
        agent_id: str,
        lock_type: LockType = LockType.EXCLUSIVE,
        timeout_minutes: int = 60
    ) -> bool:
        """
        Request access to a resource. Returns True if access granted.
        """
        return self.lock_manager.acquire_lock(resource_path, agent_id, lock_type, timeout_minutes)
    
    def release_resource_access(self, resource_path: str, agent_id: str):
        """Release access to a resource"""
        self.lock_manager.release_lock(resource_path, agent_id)
    
    def validate_changes(self, change_set: ChangeSet, allow_completed_updates: bool = False) -> Tuple[bool, List[str]]:
        """
        Validate changes before integration.
        Returns (is_valid, list_of_issues)
        """
        return self.conflict_detector.validate_integration(change_set, allow_completed_updates=allow_completed_updates)
    
    def register_changes(self, change_set: ChangeSet):
        """Register changes made by an agent"""
        self.conflict_detector.register_changes(change_set)
    
    def mark_changes_integrated(self, task_id: str):
        """Mark changes as integrated (safe to use as baseline)"""
        self.conflict_detector.mark_integrated(task_id)
    
    def create_agent_workspace(self, agent_id: str, task_id: str) -> str:
        """Create isolated workspace for agent"""
        return self.workspace_manager.create_workspace(agent_id, task_id)
    
    def start_atomic_operation(self, agent_id: str, description: str) -> str:
        """Start an atomic operation that can be rolled back"""
        operation_id = f"{agent_id}_{datetime.now().timestamp()}"
        operation = AtomicOperation(operation_id, agent_id, description)
        self.atomic_operations[operation_id] = operation
        return operation_id
    
    def commit_atomic_operation(self, operation_id: str):
        """Commit an atomic operation"""
        if operation_id in self.atomic_operations:
            self.atomic_operations[operation_id].commit()
    
    def rollback_atomic_operation(self, operation_id: str) -> List[Dict]:
        """Rollback an atomic operation"""
        if operation_id in self.atomic_operations:
            return self.atomic_operations[operation_id].rollback()
        return []
    
    def get_status(self) -> Dict:
        """Get status of conflict prevention system"""
        return {
            "locks": self.lock_manager.get_locks_status(),
            "pending_changes": len([c for c in self.conflict_detector.change_history if c.task_id not in self.conflict_detector.integrated_changes]),
            "integrated_changes": len(self.conflict_detector.integrated_changes),
            "active_operations": len([o for o in self.atomic_operations.values() if not o.committed and not o.rolled_back])
        }


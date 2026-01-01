"""
Task Configuration Parser - Reads tasks and requirements from text files
"""

import re
from typing import List, Dict, Optional, Any
from datetime import datetime
from ..agents.agent_coordinator import Task, TaskStatus
import os


class TaskConfigParser:
    """Parses tasks from Markdown/text files"""
    
    def __init__(self, project_dir: str = "."):
        self.project_dir = project_dir
        self.tasks_file = os.path.join(project_dir, "tasks.md")
        self.requirements_file = os.path.join(project_dir, "requirements.md")
    
    def parse_requirements(self) -> Dict[str, Any]:
        """Parse requirements from requirements.md"""
        if not os.path.exists(self.requirements_file):
            return {
                "overview": "",
                "features": [],
                "technical_requirements": [],
                "raw_content": ""
            }
        
        with open(self.requirements_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        requirements = {
            "overview": "",
            "features": [],
            "technical_requirements": [],
            "raw_content": content
        }
        
        # Parse sections
        sections = re.split(r'^##\s+(.+)$', content, flags=re.MULTILINE)
        
        for i in range(1, len(sections), 2):
            if i + 1 < len(sections):
                section_title = sections[i].strip()
                section_content = sections[i + 1].strip()
                
                if 'overview' in section_title.lower():
                    requirements["overview"] = section_content
                elif 'feature' in section_title.lower():
                    # Extract feature items
                    feature_items = re.findall(r'^[-*]\s*(.+)$', section_content, re.MULTILINE)
                    requirements["features"].extend(feature_items)
                elif 'technical' in section_title.lower() or 'requirement' in section_title.lower():
                    # Extract requirement items
                    req_items = re.findall(r'^[-*]\s*(.+)$', section_content, re.MULTILINE)
                    requirements["technical_requirements"].extend(req_items)
        
        return requirements
    
    def parse_tasks(self, reset_statuses: bool = False) -> List[Task]:
        """
        Parse tasks from tasks.md
        
        Args:
            reset_statuses: If True, reset all task statuses to PENDING/READY based on dependencies
                           (useful for starting from scratch)
        """
        if not os.path.exists(self.tasks_file):
            return []
        
        with open(self.tasks_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        tasks = []
        
        # Find all task blocks (between ### task-id and the next heading or end)
        #
        # CRITICAL: The previous regex intentionally excluded '#' characters inside a task block.
        # That caused tasks immediately followed by phase headers like '## Phase X' to NOT be parsed
        # (because the parser couldn't consume the '##' line and also couldn't stop at it).
        #
        # We instead stop task blocks at the next '###' task header OR a '##' section header.
        # This keeps phase headers out of task bodies and ensures tasks are always parsed.
        task_pattern = r'^###\s+([^\n]+)\s*\n(.*?)(?=^###\s+|^##\s+|\Z)'
        matches = re.finditer(task_pattern, content, re.MULTILINE | re.DOTALL)
        
        for match in matches:
            task_id = match.group(1).strip()
            task_content = match.group(2).strip()
            
            # Parse task fields
            task_data = self._parse_task_block(task_id, task_content)
            if task_data:
                # If reset_statuses is True, reset task status and progress
                if reset_statuses:
                    # Reset status to PENDING (will be updated to READY by coordinator if no dependencies)
                    task_data["status"] = TaskStatus.PENDING
                    task_data["progress"] = 0
                    task_data["assigned_agent"] = None
                    task_data["started_at"] = None
                    task_data["completed_at"] = None
                    task_data["blocker_message"] = None
                    # Keep artifacts and other metadata
                
                tasks.append(self._create_task_from_dict(task_data))
        
        return tasks
    
    def _parse_task_block(self, task_id: str, content: str) -> Optional[Dict[str, Any]]:
        """Parse a single task block"""
        # Field-marker regex used to terminate multi-line fields (description, dependencies, artifacts, etc.).
        # IMPORTANT: tasks.md commonly uses bullet-style keys like "- Acceptance Criteria:" and "- Estimated Hours:".
        # The previous terminator pattern matched only the first word (e.g., "Acceptance:") which fails for
        # "Acceptance Criteria:" and caused subsequent sections to be swallowed into dependencies/artifacts.
        _FIELD_MARKER = r'^-?\s*(?:Status|Progress|Estimated(?:\s+Hours?)?|Dependencies|Assigned(?:\s+Agent)?|Created|Started|Completed|Artifacts|Acceptance(?:\s+Criteria)?|Blocker(?:\s+Type)?)\s*:'

        task_data = {
            "id": task_id,
            "title": "",
            "description": "",
            "estimated_hours": 1.0,
            "status": TaskStatus.PENDING,
            "progress": 0,
            "dependencies": [],
            "assigned_agent": None,
            "created_at": None,
            "started_at": None,
            "completed_at": None,
            "acceptance_criteria": [],
            "artifacts": [],
            "blocker_message": None,
            "blocker_type": None,
            "metadata": {}
        }
        
        # Extract fields
        title_match = re.search(r'^-?\s*Title:\s*(.+)$', content, re.MULTILINE)
        if title_match:
            task_data["title"] = title_match.group(1).strip()
        else:
            # Use task ID as title if no title found
            task_data["title"] = task_id.replace('-', ' ').title()
        
        # Description (can be multi-line, everything after Title until next field)
        desc_match = re.search(rf'^-?\s*Description:\s*(.+?)(?={_FIELD_MARKER}|\Z)',
                              content, re.MULTILINE | re.DOTALL)
        if desc_match:
            task_data["description"] = desc_match.group(1).strip()
        
        # Status
        status_match = re.search(r'^-?\s*Status:\s*([^\n]+)', content, re.MULTILINE)
        if status_match:
            status_str = status_match.group(1).strip().lower().replace(' ', '_')
            # Map common variations
            status_map = {
                "pending": TaskStatus.PENDING,
                "ready": TaskStatus.READY,
                "in_progress": TaskStatus.IN_PROGRESS,
                "in progress": TaskStatus.IN_PROGRESS,
                "assigned": TaskStatus.ASSIGNED,
                "blocked": TaskStatus.BLOCKED,
                "review": TaskStatus.REVIEW,
                "completed": TaskStatus.COMPLETED,
                "done": TaskStatus.COMPLETED,
                "failed": TaskStatus.FAILED
            }
            task_data["status"] = status_map.get(status_str, TaskStatus.PENDING)
        
        # Progress
        progress_match = re.search(r'^-?\s*Progress:\s*(\d+)', content, re.MULTILINE)
        if progress_match:
            task_data["progress"] = int(progress_match.group(1))
        
        # Estimated Hours
        hours_match = re.search(r'^-?\s*Estimated Hours?:\s*([\d.]+)', content, re.MULTILINE)
        if hours_match:
            task_data["estimated_hours"] = float(hours_match.group(1))
        
        # Dependencies
        # IMPORTANT: dependencies are line-oriented. In practice, tasks.md blocks often contain
        # non-dashed lines (e.g., "Artifacts: ..."). The previous pattern only stopped at lines
        # starting with "-", so it could accidentally swallow "Artifacts:" into the dependency list,
        # creating fake dependencies like "Artifacts: lib/foo.dart" and deadlocking the project.
        deps_match = re.search(
            rf'^-?\s*Dependencies:\s*(.+?)(?={_FIELD_MARKER}|\Z)',
            content,
            re.MULTILINE | re.DOTALL
        )
        if deps_match:
            deps_str = deps_match.group(1).strip()
            # Handle "none", "no dependencies", etc. as empty list (case-insensitive check)
            deps_str_lower = deps_str.lower()
            if deps_str_lower in ['none', 'no dependencies', 'no deps', 'n/a', 'na', '']:
                task_data["dependencies"] = []
            else:
                # Split by comma or newline
                # CRITICAL: Don't lowercase task IDs - preserve original case
                deps = [d.strip() for d in re.split(r'[,;\n]', deps_str) if d.strip()]
                # Filter out "none" if it appears in the list (case-insensitive)
                deps = [d for d in deps if d.lower() not in ['none', 'no dependencies', 'no deps', 'n/a', 'na']]
                # Filter out accidental non-task tokens (common corruption):
                # - section headers accidentally captured (e.g., "- Acceptance Criteria:")
                # - artifacts/file paths accidentally appended
                # - freeform bullet items
                cleaned_deps: List[str] = []
                for d in deps:
                    d_norm = d.replace("\\", "/").strip()
                    d_id = d_norm.lstrip("- ").strip()
                    d_id_l = d_id.lower()
                    if not d_id or d_id_l in {"acceptance criteria:", "acceptance criteria", "acceptance:", "acceptance"}:
                        continue
                    if d_id_l.startswith("artifacts:") or d_id_l.startswith("artifact:"):
                        continue
                    if re.match(r'^(lib|test|android|ios|web|windows|linux|macos)/', d_norm, flags=re.IGNORECASE):
                        continue
                    # Dependencies are task IDs; keep only those to avoid deadlocks due to stray tokens.
                    # Support both numeric task IDs (task-001) and slugged IDs (task-001-verify-flutter-sdk).
                    if re.fullmatch(r"task-[A-Za-z0-9][A-Za-z0-9-]*", d_id):
                        cleaned_deps.append(d_id)
                task_data["dependencies"] = cleaned_deps
        
        # Assigned Agent
        agent_match = re.search(r'^-?\s*Assigned Agent:\s*(.+)', content, re.MULTILINE)
        if agent_match:
            task_data["assigned_agent"] = agent_match.group(1).strip()
        
        # Dates
        for date_field in ["created", "started", "completed"]:
            date_match = re.search(rf'^-?\s*{date_field.capitalize()}:\s*([^\n]+)', content, re.MULTILINE)
            if date_match:
                date_str = date_match.group(1).strip()
                try:
                    # Try parsing various date formats
                    for fmt in ["%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%Y-%m-%dT%H:%M:%S"]:
                        try:
                            task_data[f"{date_field}_at"] = datetime.strptime(date_str, fmt)
                            break
                        except:
                            continue
                except:
                    pass
        
        # Artifacts
        artifacts_match = re.search(
            rf'^-?\s*Artifacts:\s*(.+?)(?={_FIELD_MARKER}|\Z)',
            content,
            re.MULTILINE | re.DOTALL
        )
        if artifacts_match:
            artifacts_str = artifacts_match.group(1).strip()
            artifacts = [a.strip() for a in re.split(r'[,;\n]', artifacts_str) if a.strip()]
            cleaned_artifacts: List[str] = []
            for a in artifacts:
                a_norm = a.replace("\\", "/").strip()
                a_norm_l = a_norm.lower().lstrip("- ").strip()
                if not a_norm:
                    continue
                if a_norm_l.startswith("acceptance criteria") or a_norm_l.startswith("artifact exists"):
                    continue
                if a_norm_l.startswith("artifacts:") or a_norm_l.startswith("artifact:"):
                    continue
                cleaned_artifacts.append(a_norm)
            task_data["artifacts"] = cleaned_artifacts
        
        # Acceptance Criteria
        criteria_match = re.search(
            rf'^-?\s*Acceptance Criteria:\s*(.+?)(?={_FIELD_MARKER}|\Z)',
            content,
            re.MULTILINE | re.DOTALL
        )
        if criteria_match:
            criteria_str = criteria_match.group(1).strip()
            # Prefer line-based bullet extraction to handle indentation like "  - foo".
            criteria = [m.group(1).strip() for m in re.finditer(r'^\s*[-*]\s*(.+)$', criteria_str, re.MULTILINE)]
            # Fallback: if criteria is a blob without bullets.
            if not criteria and criteria_str:
                criteria = [criteria_str]
            task_data["acceptance_criteria"] = [c for c in criteria if c]
        
        # Blocker Message
        blocker_match = re.search(r'^-?\s*Blocker:\s*(.+)', content, re.MULTILINE)
        if blocker_match:
            task_data["blocker_message"] = blocker_match.group(1).strip()

        # Blocker Type (optional, generic metadata)
        blocker_type_match = re.search(r'^-?\s*Blocker Type:\s*(.+)', content, re.MULTILINE)
        if blocker_type_match:
            task_data["blocker_type"] = blocker_type_match.group(1).strip().lower()
        
        # Metadata (JSON format)
        metadata_match = re.search(r'^-?\s*Metadata:\s*(.+?)(?=^-|\Z)', content, re.MULTILINE | re.DOTALL)
        if metadata_match:
            metadata_str = metadata_match.group(1).strip()
            try:
                import json
                task_data["metadata"] = json.loads(metadata_str)
            except:
                # If JSON parsing fails, try to extract key-value pairs
                task_data["metadata"] = {}
        
        return task_data
    
    def _create_task_from_dict(self, data: Dict[str, Any]) -> Task:
        """Create a Task object from parsed data"""
        task = Task(
            id=data["id"],
            title=data["title"],
            description=data["description"],
            estimated_hours=data["estimated_hours"],
            dependencies=data["dependencies"],
            assigned_agent=data["assigned_agent"],
            status=data["status"],
            progress=data["progress"],
            acceptance_criteria=data["acceptance_criteria"],
            artifacts=data["artifacts"],
            blocker_message=data["blocker_message"],
            blocker_type=data.get("blocker_type"),
            metadata=data.get("metadata", {})
        )
        
        if data.get("created_at"):
            task.created_at = data["created_at"]
        if data.get("started_at"):
            task.started_at = data["started_at"]
        if data.get("completed_at"):
            task.completed_at = data["completed_at"]
        
        return task
    
    def update_task_in_file(self, task: Task):
        """Update a task's status in the tasks.md file"""
        if not os.path.exists(self.tasks_file):
            return False
        
        with open(self.tasks_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Find the task block.
        #
        # IMPORTANT: Keep this consistent with parse_tasks().
        # Tasks are separated by either the next "###" task header OR a "##" section header.
        # The previous pattern did not stop at "##" headers and also effectively rejected '#'
        # within a task block, causing updates to silently fail for tasks followed by "## ...".
        task_pattern = rf'^(###\s+{re.escape(task.id)}\s*\n)(.*?)(?=^###\s+|^##\s+|\Z)'
        match = re.search(task_pattern, content, re.MULTILINE | re.DOTALL)
        
        if not match:
            # Task block not found in file. This can happen for dynamically created tasks
            # (e.g., verification/fix-up tasks). Append a new task block so the task is
            # persisted and survives restarts.
            deps_str = ", ".join(task.dependencies) if task.dependencies else "none"
            criteria_lines = []
            if getattr(task, "acceptance_criteria", None):
                for c in task.acceptance_criteria:
                    if c:
                        criteria_lines.append(f"  - {str(c).strip()}")
            if not criteria_lines:
                criteria_lines = ["  - Task completes successfully"]

            appended = "\n" + "\n".join([
                f"### {task.id}",
                f"- Title: {task.title}",
                f"- Description: {task.description}",
                f"Status: {task.status.value}",
                f"Progress: {task.progress}",
                f"- Estimated Hours: {getattr(task, 'estimated_hours', 0) or 0}",
                f"- Dependencies: {deps_str}",
                "- Acceptance Criteria:",
                *criteria_lines,
                ""
            ])

            with open(self.tasks_file, 'a', encoding='utf-8') as f:
                f.write(appended)
            return True
        
        task_block = match.group(2)
        
        # Update status
        if re.search(r'^-?\s*Status:\s*\w+', task_block, re.MULTILINE):
            task_block = re.sub(r'^-?\s*Status:\s*\w+', f'Status: {task.status.value}', task_block, flags=re.MULTILINE)
        else:
            # Add status if not present
            task_block = f"Status: {task.status.value}\n{task_block}"
        
        # Update progress
        if re.search(r'^-?\s*Progress:\s*\d+', task_block, re.MULTILINE):
            task_block = re.sub(r'^-?\s*Progress:\s*\d+', f'Progress: {task.progress}', task_block, flags=re.MULTILINE)
        else:
            task_block = f"Progress: {task.progress}\n{task_block}"
        
        # Update assigned agent
        if task.assigned_agent:
            if re.search(r'^-?\s*Assigned Agent:\s*.+', task_block, re.MULTILINE):
                task_block = re.sub(r'^-?\s*Assigned Agent:\s*.+', f'Assigned Agent: {task.assigned_agent}', task_block, flags=re.MULTILINE)
            else:
                task_block = f"Assigned Agent: {task.assigned_agent}\n{task_block}"
        else:
            # Clear assigned agent if task is completed or not assigned
            # This ensures completed tasks don't have assigned agents in tasks.md
            if re.search(r'^-?\s*Assigned Agent:\s*.+', task_block, re.MULTILINE):
                task_block = re.sub(r'^-?\s*Assigned Agent:\s*.+\n?', '', task_block, flags=re.MULTILINE)
        
        # Update dates
        if task.started_at:
            if re.search(r'^-?\s*Started:\s*.+', task_block, re.MULTILINE):
                task_block = re.sub(r'^-?\s*Started:\s*.+', f'Started: {task.started_at.strftime("%Y-%m-%d %H:%M:%S")}', task_block, flags=re.MULTILINE)
            else:
                task_block = f"Started: {task.started_at.strftime('%Y-%m-%d %H:%M:%S')}\n{task_block}"
        
        if task.completed_at:
            if re.search(r'^-?\s*Completed:\s*.+', task_block, re.MULTILINE):
                task_block = re.sub(r'^-?\s*Completed:\s*.+', f'Completed: {task.completed_at.strftime("%Y-%m-%d %H:%M:%S")}', task_block, flags=re.MULTILINE)
            else:
                task_block = f"Completed: {task.completed_at.strftime('%Y-%m-%d %H:%M:%S')}\n{task_block}"
        
        # Update artifacts
        if task.artifacts:
            artifacts_str = ', '.join(task.artifacts)
            # Replace only the Artifacts line (line-based).
            # The previous DOTALL pattern could "eat" into following fields and also
            # accidentally join lines (e.g., "Artifacts: ...- Dependencies: ...").
            if re.search(r'^-?\s*Artifacts:\s*.*$', task_block, re.MULTILINE):
                task_block = re.sub(
                    r'^-?\s*Artifacts:\s*.*$',
                    f'Artifacts: {artifacts_str}',
                    task_block,
                    flags=re.MULTILINE
                )
            else:
                task_block = f"Artifacts: {artifacts_str}\n{task_block}"
        
        # Update blocker message
        if task.blocker_message:
            if re.search(r'^-?\s*Blocker:\s*.*$', task_block, re.MULTILINE):
                task_block = re.sub(
                    r'^-?\s*Blocker:\s*.*$',
                    f'Blocker: {task.blocker_message}',
                    task_block,
                    flags=re.MULTILINE
                )
            else:
                task_block = f"Blocker: {task.blocker_message}\n{task_block}"
        else:
            # Clear blocker message if task is completed or not blocked
            # This ensures completed tasks don't have blocker messages in tasks.md
            if re.search(r'^-?\s*Blocker:\s*.+', task_block, re.MULTILINE):
                task_block = re.sub(r'^-?\s*Blocker:\s*.+\n?', '', task_block, flags=re.MULTILINE)

        # Update blocker type (optional, generic metadata)
        blocker_type_val = getattr(task, "blocker_type", None)
        if blocker_type_val:
            if re.search(r'^-?\s*Blocker Type:\s*.*$', task_block, re.MULTILINE):
                task_block = re.sub(
                    r'^-?\s*Blocker Type:\s*.*$',
                    f'Blocker Type: {blocker_type_val}',
                    task_block,
                    flags=re.MULTILINE
                )
            else:
                task_block = f"Blocker Type: {blocker_type_val}\n{task_block}"
        else:
            if re.search(r'^-?\s*Blocker Type:\s*.+', task_block, re.MULTILINE):
                task_block = re.sub(r'^-?\s*Blocker Type:\s*.+\n?', '', task_block, flags=re.MULTILINE)
        
        # Replace the task block in content
        new_content = content[:match.start(2)] + task_block + content[match.end(2):]
        
        # Write back to file
        with open(self.tasks_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        return True
    
    def reset_all_task_statuses(self):
        """
        Reset all task statuses in tasks.md to PENDING/READY for fresh start.
        Keeps task definitions but resets status, progress, assigned agents, and timestamps.
        """
        if not os.path.exists(self.tasks_file):
            return False
        
        with open(self.tasks_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Reset Status lines
        content = re.sub(r'^-?\s*Status:\s*completed', 'Status: pending', content, flags=re.MULTILINE | re.IGNORECASE)
        content = re.sub(r'^-?\s*Status:\s*in_progress', 'Status: pending', content, flags=re.MULTILINE | re.IGNORECASE)
        content = re.sub(r'^-?\s*Status:\s*blocked', 'Status: pending', content, flags=re.MULTILINE | re.IGNORECASE)
        content = re.sub(r'^-?\s*Status:\s*ready', 'Status: pending', content, flags=re.MULTILINE | re.IGNORECASE)
        
        # Reset Progress to 0
        content = re.sub(r'^-?\s*Progress:\s*\d+', 'Progress: 0', content, flags=re.MULTILINE)
        
        # Remove Assigned Agent lines
        content = re.sub(r'^-?\s*Assigned Agent:\s*.+\n?', '', content, flags=re.MULTILINE)
        
        # Remove Started and Completed timestamps
        content = re.sub(r'^-?\s*Started:\s*.+\n?', '', content, flags=re.MULTILINE)
        content = re.sub(r'^-?\s*Completed:\s*.+\n?', '', content, flags=re.MULTILINE)
        
        # Remove Blocker messages
        content = re.sub(r'^-?\s*Blocker:\s*.+\n?', '', content, flags=re.MULTILINE)
        
        # Write back to file
        with open(self.tasks_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return True


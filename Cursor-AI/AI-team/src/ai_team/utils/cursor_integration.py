"""
Cursor Integration - Tools and adapters for Cursor editor integration.
Allows Cursor agents to work within the protocol.
"""

import subprocess
import json
import os
from typing import Dict, List, Optional, Any
from pathlib import Path
from tool_system import Tool, ToolResult
from task_adapter import TaskAdapter, TaskContext
from ..agents.agent_coordinator import Task


class CursorTool(Tool):
    """
    Tool for interfacing with Cursor editor.
    Supports various Cursor operations like file editing, code generation, etc.
    """
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        super().__init__("cursor", config)
        self.cursor_path = config.get('cursor_path', 'cursor') if config else 'cursor'
        self.workspace_base = config.get('workspace_base', '.') if config else '.'
    
    def validate(self, *args, **kwargs) -> tuple[bool, Optional[str]]:
        """Validate tool inputs"""
        if 'operation' not in kwargs:
            return False, "Missing 'operation' parameter"
        operation = kwargs.get('operation')
        
        # Validate operation-specific parameters
        if operation == 'edit_file' and 'file_path' not in kwargs:
            return False, "edit_file requires 'file_path' parameter"
        if operation == 'create_file' and 'file_path' not in kwargs:
            return False, "create_file requires 'file_path' parameter"
        if operation == 'generate_code' and 'prompt' not in kwargs:
            return False, "generate_code requires 'prompt' parameter"
        
        return True, None
    
    def execute(self, *args, **kwargs) -> ToolResult:
        """Execute Cursor operation"""
        operation = kwargs.get('operation')
        
        try:
            if operation == 'edit_file':
                return self._edit_file(**kwargs)
            elif operation == 'create_file':
                return self._create_file(**kwargs)
            elif operation == 'generate_code':
                return self._generate_code(**kwargs)
            elif operation == 'read_file':
                return self._read_file(**kwargs)
            elif operation == 'list_files':
                return self._list_files(**kwargs)
            elif operation == 'run_command':
                return self._run_command(**kwargs)
            else:
                return ToolResult(
                    success=False,
                    error=f"Unknown operation: {operation}"
                )
        except Exception as e:
            return ToolResult(
                success=False,
                error=f"Cursor operation failed: {str(e)}"
            )
    
    def _edit_file(self, file_path: str, content: Optional[str] = None, 
                   edits: Optional[List[Dict]] = None, **kwargs) -> ToolResult:
        """Edit a file using Cursor"""
        full_path = os.path.join(self.workspace_base, file_path)
        
        # Ensure directory exists
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        
        if content:
            # Write entire file content
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)
        elif edits:
            # Apply edits (line-based or range-based)
            if os.path.exists(full_path):
                with open(full_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            else:
                lines = []
            
            # Apply edits
            for edit in edits:
                if 'line' in edit and 'text' in edit:
                    line_num = edit['line'] - 1  # 0-indexed
                    if line_num < len(lines):
                        lines[line_num] = edit['text'] + '\n'
                    else:
                        lines.append(edit['text'] + '\n')
                elif 'range' in edit and 'text' in edit:
                    start_line = edit['range']['start']['line']
                    end_line = edit['range']['end']['line']
                    replacement = edit['text']
                    lines[start_line:end_line+1] = [replacement + '\n']
            
            with open(full_path, 'w', encoding='utf-8') as f:
                f.writelines(lines)
        else:
            return ToolResult(success=False, error="No content or edits provided")
        
        return ToolResult(
            success=True,
            output=f"File edited: {file_path}",
            metadata={"file_path": file_path, "operation": "edit"}
        )
    
    def _create_file(self, file_path: str, content: str = "", **kwargs) -> ToolResult:
        """Create a new file"""
        full_path = os.path.join(self.workspace_base, file_path)
        
        # Ensure directory exists
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return ToolResult(
            success=True,
            output=f"File created: {file_path}",
            metadata={"file_path": file_path, "operation": "create"}
        )
    
    def _read_file(self, file_path: str, **kwargs) -> ToolResult:
        """Read file content"""
        full_path = os.path.join(self.workspace_base, file_path)
        
        if not os.path.exists(full_path):
            return ToolResult(
                success=False,
                error=f"File not found: {file_path}"
            )
        
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        return ToolResult(
            success=True,
            output=content,
            metadata={"file_path": file_path, "operation": "read"}
        )
    
    def _list_files(self, directory: str = ".", pattern: Optional[str] = None, **kwargs) -> ToolResult:
        """List files in directory"""
        full_path = os.path.join(self.workspace_base, directory)
        
        if not os.path.exists(full_path):
            return ToolResult(
                success=False,
                error=f"Directory not found: {directory}"
            )
        
        files = []
        for root, dirs, filenames in os.walk(full_path):
            for filename in filenames:
                if pattern is None or pattern in filename:
                    rel_path = os.path.relpath(os.path.join(root, filename), self.workspace_base)
                    files.append(rel_path)
        
        return ToolResult(
            success=True,
            output=files,
            metadata={"directory": directory, "count": len(files)}
        )
    
    def _generate_code(self, prompt: str, file_path: Optional[str] = None, 
                      language: str = "python", **kwargs) -> ToolResult:
        """
        Generate code based on prompt.
        In a real implementation, this would interface with Cursor's AI features.
        For now, this is a placeholder that creates a basic file structure.
        """
        if file_path:
            # Create file with generated code structure
            content = f"# Generated code based on: {prompt}\n"
            content += f"# Language: {language}\n\n"
            content += "# TODO: Implement based on prompt\n"
            
            if language == "python":
                content += "def main():\n    pass\n\n"
                content += "if __name__ == '__main__':\n    main()\n"
            elif language == "javascript":
                content += "function main() {\n    // Implementation\n}\n\n"
                content += "main();\n"
            
            return self._create_file(file_path, content)
        else:
            return ToolResult(
                success=True,
                output=f"Code generation prompt: {prompt}",
                metadata={"prompt": prompt, "language": language}
            )
    
    def _run_command(self, command: str, cwd: Optional[str] = None, **kwargs) -> ToolResult:
        """Run a command in the workspace"""
        work_dir = os.path.join(self.workspace_base, cwd) if cwd else self.workspace_base
        
        try:
            result = subprocess.run(
                command,
                shell=True,
                cwd=work_dir,
                capture_output=True,
                text=True,
                timeout=kwargs.get('timeout', 30)
            )
            
            return ToolResult(
                success=result.returncode == 0,
                output=result.stdout,
                error=result.stderr if result.returncode != 0 else None,
                metadata={
                    "command": command,
                    "returncode": result.returncode,
                    "cwd": work_dir
                }
            )
        except subprocess.TimeoutExpired:
            return ToolResult(
                success=False,
                error=f"Command timed out: {command}"
            )
        except Exception as e:
            return ToolResult(
                success=False,
                error=f"Command execution failed: {str(e)}"
            )


class CursorTaskAdapter(TaskAdapter):
    """
    Adapter for tasks that use Cursor for execution.
    Handles coding tasks that should be executed via Cursor.
    """
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        super().__init__("cursor", config)
        self.cursor_tool: Optional[CursorTool] = None
    
    def set_cursor_tool(self, cursor_tool: CursorTool):
        """Set the Cursor tool to use"""
        self.cursor_tool = cursor_tool
    
    def can_handle(self, task: Task) -> bool:
        """Check if task should use Cursor"""
        # Check metadata
        if hasattr(task, 'metadata') and task.metadata:
            if task.metadata.get('use_cursor', False):
                return True
            if task.metadata.get('type') == 'cursor':
                return True
        
        # Check keywords in title/description
        text = f"{task.title} {task.description}".lower()
        cursor_keywords = ['cursor', 'code', 'implement', 'write', 'create', 'edit']
        coding_keywords = ['function', 'class', 'module', 'api', 'script', 'file']
        
        has_cursor_keyword = any(kw in text for kw in cursor_keywords)
        has_coding_keyword = any(kw in text for kw in coding_keywords)
        
        return has_cursor_keyword or (has_coding_keyword and 'cursor' in text)
    
    def validate_task(self, task: Task) -> tuple[bool, List[str]]:
        """Validate Cursor task"""
        issues = []
        
        if not self.cursor_tool:
            issues.append("Cursor tool not configured")
        
        if not task.description:
            issues.append("Task needs description for Cursor execution")
        
        return len(issues) == 0, issues
    
    def prepare_context(self, task: Task, agent_id: str) -> TaskContext:
        """Prepare context for Cursor task"""
        context = TaskContext(
            task=task,
            agent_id=agent_id,
            config=self.config.copy(),
            metadata=task.metadata.copy() if hasattr(task, 'metadata') and task.metadata else {}
        )
        
        # Set workspace path
        if context.workspace_path:
            context.config['workspace_base'] = context.workspace_path
        else:
            context.config['workspace_base'] = self.config.get('workspace_base', 'workspaces')
        
        return context
    
    def execute(self, context: TaskContext) -> bool:
        """Execute task using Cursor"""
        if not self.cursor_tool:
            return False
        
        task = context.task
        workspace_base = context.config.get('workspace_base', 'workspaces')
        
        # Determine what files to create/edit based on task
        artifacts = []
        
        # Extract file information from task
        if 'file_path' in context.metadata:
            file_path = context.metadata['file_path']
        else:
            # Generate file path from task
            file_path = f"src/{task.id}.py"
        
        # Determine language
        language = context.metadata.get('language', 'python')
        if language == 'python':
            ext = '.py'
        elif language == 'javascript':
            ext = '.js'
        elif language == 'typescript':
            ext = '.ts'
        else:
            ext = '.py'
        
        if not file_path.endswith(ext):
            file_path = file_path.rsplit('.', 1)[0] + ext
        
        # Generate code using Cursor tool
        prompt = f"{task.title}: {task.description}"
        result = self.cursor_tool.execute(
            operation='generate_code',
            prompt=prompt,
            file_path=file_path,
            language=language
        )
        
        if not result.success:
            return False
        
        # If there's additional content in metadata, edit the file
        if 'code_content' in context.metadata:
            edit_result = self.cursor_tool.execute(
                operation='edit_file',
                file_path=file_path,
                content=context.metadata['code_content']
            )
            if not edit_result.success:
                return False
        
        # Store artifacts
        context.metadata['artifacts'] = [file_path]
        artifacts.append(file_path)
        
        # Create test file if needed
        if context.metadata.get('create_tests', True):
            test_file = f"tests/test_{task.id}.py"
            test_content = f"# Tests for {task.title}\n\n"
            test_content += "def test_{}():\n    pass\n".format(task.id.replace('-', '_'))
            
            test_result = self.cursor_tool.execute(
                operation='create_file',
                file_path=test_file,
                content=test_content
            )
            
            if test_result.success:
                artifacts.append(test_file)
        
        context.metadata['artifacts'] = artifacts
        return True
    
    def get_artifacts(self, context: TaskContext) -> List[str]:
        """Get artifacts created by Cursor"""
        return context.metadata.get('artifacts', [])


def create_cursor_tool_registry(workspace_base: str = "workspaces") -> tuple[CursorTool, 'ToolRegistry']:
    """Create a tool registry with Cursor tool"""
    from tool_system import ToolRegistry
    
    registry = ToolRegistry()
    cursor_tool = CursorTool(config={'workspace_base': workspace_base})
    registry.register(cursor_tool, category="editor")
    
    return cursor_tool, registry


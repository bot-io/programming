"""
Tool System - Extensible tooling for task execution.
Allows adding tools/plugins for different capabilities.
"""

from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any, Callable, Type
from dataclasses import dataclass
from datetime import datetime
from .task_adapter import TaskContext


@dataclass
class ToolResult:
    """Result from tool execution"""
    success: bool
    output: Any = None
    error: Optional[str] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class Tool(ABC):
    """
    Base class for tools that can be used by agents.
    Tools provide specific capabilities (file operations, API calls, etc.)
    """
    
    def __init__(self, name: str, config: Optional[Dict[str, Any]] = None):
        self.name = name
        self.config = config or {}
    
    @abstractmethod
    def execute(self, *args, **kwargs) -> ToolResult:
        """Execute the tool. Returns ToolResult."""
        pass
    
    @abstractmethod
    def validate(self, *args, **kwargs) -> tuple[bool, Optional[str]]:
        """Validate tool inputs. Returns (is_valid, error_message)"""
        pass
    
    def get_info(self) -> Dict[str, Any]:
        """Get tool information"""
        return {
            "name": self.name,
            "config": self.config
        }


class ToolRegistry:
    """
    Registry for tools.
    Agents can discover and use registered tools.
    """
    
    def __init__(self):
        self.tools: Dict[str, Tool] = {}
        self.tool_categories: Dict[str, List[str]] = {}
    
    def register(self, tool: Tool, category: str = "general"):
        """Register a tool"""
        self.tools[tool.name] = tool
        if category not in self.tool_categories:
            self.tool_categories[category] = []
        self.tool_categories[category].append(tool.name)
    
    def get(self, name: str) -> Optional[Tool]:
        """Get a tool by name"""
        return self.tools.get(name)
    
    def get_by_category(self, category: str) -> List[Tool]:
        """Get all tools in a category"""
        tool_names = self.tool_categories.get(category, [])
        return [self.tools[name] for name in tool_names if name in self.tools]
    
    def list_all(self) -> List[str]:
        """List all available tool names"""
        return list(self.tools.keys())
    
    def list_categories(self) -> List[str]:
        """List all tool categories"""
        return list(self.tool_categories.keys())


class ToolExecutor:
    """
    Executes tools with context and error handling.
    """
    
    def __init__(self, registry: ToolRegistry, context: Optional[TaskContext] = None):
        self.registry = registry
        self.context = context
        self.execution_history: List[Dict[str, Any]] = []
    
    def execute(self, tool_name: str, *args, **kwargs) -> ToolResult:
        """Execute a tool"""
        tool = self.registry.get(tool_name)
        if not tool:
            return ToolResult(
                success=False,
                error=f"Tool '{tool_name}' not found"
            )
        
        # Validate
        is_valid, error = tool.validate(*args, **kwargs)
        if not is_valid:
            return ToolResult(success=False, error=error)
        
        # Execute
        try:
            result = tool.execute(*args, **kwargs)
            
            # Record execution
            self.execution_history.append({
                "tool": tool_name,
                "success": result.success,
                "timestamp": datetime.now().isoformat(),
                "context": self.context.task.id if self.context else None
            })
            
            return result
        except Exception as e:
            return ToolResult(
                success=False,
                error=f"Tool execution error: {str(e)}"
            )
    
    def get_history(self) -> List[Dict[str, Any]]:
        """Get execution history"""
        return self.execution_history.copy()


# Built-in tool examples

class FileSystemTool(Tool):
    """Tool for file system operations"""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        super().__init__("filesystem", config)
    
    def validate(self, *args, **kwargs) -> tuple[bool, Optional[str]]:
        if 'operation' not in kwargs:
            return False, "Missing 'operation' parameter"
        return True, None
    
    def execute(self, *args, **kwargs) -> ToolResult:
        operation = kwargs.get('operation')
        # Simplified implementation
        # In real implementation, would do actual file operations
        return ToolResult(
            success=True,
            output=f"File operation '{operation}' completed",
            metadata={"operation": operation}
        )


class APITool(Tool):
    """Tool for API calls"""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        super().__init__("api", config)
        self.base_url = config.get('base_url', '') if config else ''
    
    def validate(self, *args, **kwargs) -> tuple[bool, Optional[str]]:
        if 'endpoint' not in kwargs:
            return False, "Missing 'endpoint' parameter"
        return True, None
    
    def execute(self, *args, **kwargs) -> ToolResult:
        endpoint = kwargs.get('endpoint')
        method = kwargs.get('method', 'GET')
        # Simplified implementation
        return ToolResult(
            success=True,
            output=f"API {method} {endpoint} completed",
            metadata={"endpoint": endpoint, "method": method}
        )


class CodeExecutionTool(Tool):
    """Tool for executing code"""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        super().__init__("code_execution", config)
        self.language = config.get('language', 'python') if config else 'python'
    
    def validate(self, *args, **kwargs) -> tuple[bool, Optional[str]]:
        if 'code' not in kwargs:
            return False, "Missing 'code' parameter"
        return True, None
    
    def execute(self, *args, **kwargs) -> ToolResult:
        code = kwargs.get('code')
        # Simplified implementation - would execute code in real system
        return ToolResult(
            success=True,
            output=f"Code execution completed for {self.language}",
            metadata={"language": self.language, "code_length": len(code) if code else 0}
        )


def create_default_tool_registry() -> ToolRegistry:
    """Create a registry with default tools"""
    registry = ToolRegistry()
    
    # Register built-in tools
    registry.register(FileSystemTool(), "filesystem")
    registry.register(APITool(), "network")
    registry.register(CodeExecutionTool(), "execution")
    
    return registry


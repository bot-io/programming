"""
Task Configuration System - Domain-specific configurations.
Allows customizing the protocol for different task domains.
"""

from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field
from .task_adapter import TaskConfig
import json
import os


@dataclass
class DomainConfig:
    """Configuration for a specific task domain"""
    domain_name: str
    task_types: List[str] = field(default_factory=list)
    agent_specializations: List[str] = field(default_factory=list)
    default_adapters: Dict[str, str] = field(default_factory=dict)  # task_type -> adapter_type
    tool_categories: List[str] = field(default_factory=list)
    config_overrides: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "domain_name": self.domain_name,
            "task_types": self.task_types,
            "agent_specializations": self.agent_specializations,
            "default_adapters": self.default_adapters,
            "tool_categories": self.tool_categories,
            "config_overrides": self.config_overrides
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'DomainConfig':
        return cls(
            domain_name=data["domain_name"],
            task_types=data.get("task_types", []),
            agent_specializations=data.get("agent_specializations", []),
            default_adapters=data.get("default_adapters", {}),
            tool_categories=data.get("tool_categories", []),
            config_overrides=data.get("config_overrides", {})
        )


class DomainConfigManager:
    """Manages domain-specific configurations"""
    
    def __init__(self):
        self.domains: Dict[str, DomainConfig] = {}
        self.default_domain: Optional[str] = None
    
    def register_domain(self, config: DomainConfig, set_default: bool = False):
        """Register a domain configuration"""
        self.domains[config.domain_name] = config
        if set_default or not self.default_domain:
            self.default_domain = config.domain_name
    
    def get_domain(self, domain_name: str) -> Optional[DomainConfig]:
        """Get domain configuration"""
        return self.domains.get(domain_name)
    
    def get_default_domain(self) -> Optional[DomainConfig]:
        """Get default domain configuration"""
        if self.default_domain:
            return self.domains.get(self.default_domain)
        return None
    
    def load_from_file(self, filepath: str):
        """Load domain configurations from file"""
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        if isinstance(data, list):
            for domain_data in data:
                config = DomainConfig.from_dict(domain_data)
                self.register_domain(config)
        elif isinstance(data, dict):
            config = DomainConfig.from_dict(data)
            self.register_domain(config, set_default=True)
    
    def save_to_file(self, filepath: str):
        """Save domain configurations to file"""
        domains_data = [domain.to_dict() for domain in self.domains.values()]
        with open(filepath, 'w') as f:
            json.dump(domains_data, f, indent=2)


# Predefined domain configurations

def create_software_development_config() -> DomainConfig:
    """Configuration for software development tasks"""
    return DomainConfig(
        domain_name="software_development",
        task_types=["coding", "testing", "documentation", "refactoring", "debugging"],
        agent_specializations=["backend", "frontend", "database", "devops", "qa"],
        default_adapters={
            "coding": "code_adapter",
            "testing": "test_adapter",
            "documentation": "doc_adapter"
        },
        tool_categories=["filesystem", "code_execution", "version_control"],
        config_overrides={
            "checkpoint_interval": 20,
            "workspace_base": "code_workspaces",
            "artifact_base": "code_artifacts"
        }
    )


def create_content_creation_config() -> DomainConfig:
    """Configuration for content creation tasks"""
    return DomainConfig(
        domain_name="content_creation",
        task_types=["writing", "editing", "research", "formatting"],
        agent_specializations=["writer", "editor", "researcher"],
        default_adapters={
            "writing": "writing_adapter",
            "editing": "editing_adapter"
        },
        tool_categories=["filesystem", "text_processing"],
        config_overrides={
            "checkpoint_interval": 15,
            "workspace_base": "content_workspaces"
        }
    )


def create_data_analysis_config() -> DomainConfig:
    """Configuration for data analysis tasks"""
    return DomainConfig(
        domain_name="data_analysis",
        task_types=["analysis", "visualization", "cleaning", "modeling"],
        agent_specializations=["analyst", "data_scientist", "visualizer"],
        default_adapters={
            "analysis": "analysis_adapter",
            "visualization": "viz_adapter"
        },
        tool_categories=["data_processing", "visualization", "statistics"],
        config_overrides={
            "checkpoint_interval": 30,
            "workspace_base": "data_workspaces"
        }
    )


def create_default_config_manager() -> DomainConfigManager:
    """Create config manager with default domains"""
    manager = DomainConfigManager()
    
    manager.register_domain(create_software_development_config(), set_default=True)
    manager.register_domain(create_content_creation_config())
    manager.register_domain(create_data_analysis_config())
    
    return manager


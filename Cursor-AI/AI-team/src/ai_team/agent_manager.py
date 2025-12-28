"""
Agent Manager - Creates and manages agent instances.
Can be used by coordinator or coordinator agents to spawn agents.
"""

from typing import Dict, List, Optional, Type, Callable
from .agents.agent_coordinator import AgentCoordinator, AgentState
from .agents.agent import Agent
import inspect


class AgentManager:
    """
    Manages agent creation and lifecycle.
    Can spawn agents on demand for coordinators.
    """
    
    def __init__(self, coordinator: AgentCoordinator):
        self.coordinator = coordinator
        self.agent_factories: Dict[str, Callable] = {}  # agent_type -> factory function
        self.created_agents: Dict[str, Agent] = {}  # agent_id -> Agent instance
    
    def register_agent_type(
        self,
        agent_type: str,
        agent_class: Type[Agent],
        default_specialization: str = ""
    ):
        """
        Register an agent type that can be spawned.
        
        Args:
            agent_type: Name/type identifier for this agent class
            agent_class: The Agent class to instantiate
            default_specialization: Default specialization for this agent type
        """
        def factory(agent_id: str, specialization: Optional[str] = None) -> Agent:
            spec = specialization or default_specialization
            return agent_class(agent_id, self.coordinator, spec)
        
        self.agent_factories[agent_type] = factory
        print(f"Registered agent type: {agent_type}")
    
    def create_agent(
        self,
        agent_id: str,
        agent_type: str,
        specialization: Optional[str] = None,
        auto_start: bool = False
    ) -> Optional[Agent]:
        """
        Create a new agent instance.
        
        Args:
            agent_id: Unique identifier for the agent
            agent_type: Type of agent to create (must be registered)
            specialization: Optional specialization override
            auto_start: If True, automatically start the agent
        
        Returns:
            Agent instance or None if creation failed
        """
        if agent_id in self.created_agents:
            print(f"Agent '{agent_id}' already exists")
            return self.created_agents[agent_id]
        
        if agent_type not in self.agent_factories:
            print(f"Error: Agent type '{agent_type}' not registered")
            return None
        
        try:
            factory = self.agent_factories[agent_type]
            agent = factory(agent_id, specialization)
            self.created_agents[agent_id] = agent
            
            if auto_start:
                self.coordinator.start_agent(agent_id)
            
            print(f"Created agent '{agent_id}' of type '{agent_type}'")
            return agent
        except Exception as e:
            print(f"Error creating agent '{agent_id}': {e}")
            return None
    
    def create_agents(
        self,
        agent_specs: List[Dict],
        auto_start: bool = False
    ) -> List[Agent]:
        """
        Create multiple agents from specifications.
        
        Args:
            agent_specs: List of dicts with keys: agent_id, agent_type, specialization (optional)
            auto_start: If True, automatically start all agents
        
        Returns:
            List of created agents
        """
        agents = []
        for spec in agent_specs:
            agent = self.create_agent(
                agent_id=spec["agent_id"],
                agent_type=spec["agent_type"],
                specialization=spec.get("specialization"),
                auto_start=auto_start
            )
            if agent:
                agents.append(agent)
        return agents
    
    def get_agent(self, agent_id: str) -> Optional[Agent]:
        """Get an agent by ID"""
        return self.created_agents.get(agent_id)
    
    def remove_agent(self, agent_id: str) -> bool:
        """Remove an agent (stops it first)"""
        if agent_id not in self.created_agents:
            return False
        
        # Stop agent first
        self.coordinator.stop_agent(agent_id)
        
        # Remove from tracking
        del self.created_agents[agent_id]
        print(f"Removed agent '{agent_id}'")
        return True
    
    def get_all_agents(self) -> Dict[str, Agent]:
        """Get all created agents"""
        return self.created_agents.copy()
    
    def start_agent(self, agent_id: str) -> bool:
        """Start an agent"""
        return self.coordinator.start_agent(agent_id)
    
    def stop_agent(self, agent_id: str) -> bool:
        """Stop an agent"""
        return self.coordinator.stop_agent(agent_id)
    
    def pause_agent(self, agent_id: str) -> bool:
        """Pause an agent"""
        return self.coordinator.pause_agent(agent_id)
    
    def resume_agent(self, agent_id: str) -> bool:
        """Resume an agent"""
        return self.coordinator.resume_agent(agent_id)
    
    def start_all_agents(self) -> Dict[str, bool]:
        """Start all managed agents"""
        results = {}
        for agent_id in self.created_agents:
            results[agent_id] = self.coordinator.start_agent(agent_id)
        return results
    
    def stop_all_agents(self) -> Dict[str, bool]:
        """Stop all managed agents"""
        results = {}
        for agent_id in self.created_agents:
            results[agent_id] = self.coordinator.stop_agent(agent_id)
        return results
    
    def get_agent_status(self) -> Dict:
        """Get status of all managed agents"""
        return {
            "total_agents": len(self.created_agents),
            "agent_states": self.coordinator.get_all_agent_states(),
            "agent_types": {
                agent_id: self._get_agent_type(agent_id)
                for agent_id in self.created_agents
            }
        }
    
    def _get_agent_type(self, agent_id: str) -> Optional[str]:
        """Get the type of an agent"""
        # Try to infer from agent class name
        agent = self.created_agents.get(agent_id)
        if agent:
            return agent.__class__.__name__
        return None


class CoordinatorAgent(Agent):
    """
    A special agent that can coordinate other agents.
    Can spawn and control other agents.
    """
    
    def __init__(self, agent_id: str, coordinator: AgentCoordinator, specialization: str = "coordinator"):
        super().__init__(agent_id, coordinator, specialization)
        self.agent_manager = AgentManager(coordinator)
    
    def spawn_agent(
        self,
        agent_id: str,
        agent_type: str,
        specialization: Optional[str] = None,
        auto_start: bool = True
    ) -> Optional[Agent]:
        """Spawn a new agent"""
        return self.agent_manager.create_agent(agent_id, agent_type, specialization, auto_start)
    
    def control_agent(self, agent_id: str, command: str) -> bool:
        """
        Control another agent.
        Commands: start, stop, pause, resume
        """
        if command == "start":
            return self.coordinator.start_agent(agent_id)
        elif command == "stop":
            return self.coordinator.stop_agent(agent_id)
        elif command == "pause":
            return self.coordinator.pause_agent(agent_id)
        elif command == "resume":
            return self.coordinator.resume_agent(agent_id)
        else:
            print(f"Unknown command: {command}")
            return False
    
    def get_agent_status(self, agent_id: str) -> Optional[AgentState]:
        """Get status of an agent"""
        return self.coordinator.get_agent_state(agent_id)
    
    def work(self, task: Task) -> bool:
        """
        Coordinator agent work - can spawn and manage other agents.
        Override this to implement coordinator-specific logic.
        """
        # Example: Coordinator can spawn agents based on task requirements
        print(f"[{self.agent_id}] Coordinator agent working on: {task.title}")
        return True


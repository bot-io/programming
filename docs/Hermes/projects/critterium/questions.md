# Critterium — Questions

_All previous questions resolved (Q1–Q8). New questions from ecosystem mode architecture._

### Q9: Free version species cap
How many species in the free version? (Paid = 12)
- Option A: 3 species (enough for basic presets)
- Option B: 5 species (enough for RPS + predator/prey)
- Option C: Other number?

### Q10: Energy system granularity
How detailed should the hunger/energy system be?
- **Simple:** Binary — hungry (seeking food) or full (ignoring food). Timer-based.
- **Medium:** Hunger bar 0–100. Below threshold → seek food. Eating fills bar. Bar depletes over time.
- **Complex:** Full energy budget — movement costs energy, eating gains energy, reproduction costs energy, different foods give different energy.

### Q11: Reproduction mechanic
How do creatures reproduce?
- **A) Binary fission:** When fed+healthy, particle splits into two (parent + child). Simple, emergent.
- **B) Proximity mating:** Two same-species particles near each other + both fed → spawn a third.
- **C) Egg/spawn point:** Fed creature drops an "egg" that hatches after a timer.

### Q12: Death mechanics
- Old age: confirmed (die after X sim-seconds)?
- Starvation: die if hunger reaches 0?
- Eaten: instant removal, or gradual (chipped away)?
- Sickness: die after sickness timer, or sickness just slows/weakens?

### Q13: Sickness center — what is it?
- **A) Fixed point on the map** — a zone that infects creatures that enter it
- **B) Contagious disease** — sick creature infects nearby healthy creatures of same species
- **C) Both** — originates from a center, then spreads contagiously

### Q14: Eating mechanic
When species A eats species B:
- **A) Instant:** A touches B → B disappears, A gains energy
- **B) Gradual:** A stays near B for X seconds → B shrinks and dies, A gains energy over time
- **C) Chase-catch:** A must be faster than B and catch it. One contact = one eat.

### Q15: Force count for paid/free
You mentioned forces/behaviors will also have a limit. Which forces are free vs paid? Current forces: attraction, repulsion, eating, hunger, aging, reproduction, flocking, wandering, flow field, vortex, drag, gravity. Any others you want?

### Q16: World boundaries for ecosystem
With birth/death, the total particle count fluctuates. Should there be:
- **A) Hard cap:** No new spawns if total > max (e.g., 1200). Oldest die naturally.
- **B) Soft cap:** Reproduction rate decreases as population grows (logistic growth).
- **C) No cap:** Let it grow. User's problem if it lags.

### Q17: Per-species interaction — distance ranges
You mentioned "attracted from distance A to B, repelled from distance B to C." Should each species pair support multiple distance bands with different forces? (e.g., attract far, repel mid, align close)

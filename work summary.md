# Work Summary

~3 days of work writing documentation and experimenting with different agent orchestration tools like gas town. The most effective one ended up just being Claude Opus with `/goal` and subagents since it is cross platform, and gas town isn't really.

For the first couple days, I needed about an hour a day to make corrections to the agents. For example, the agents wanted to run a full 30 min test suite for every commit. This was making them too slow. I had to clean that up. They also kept stopping for various reasons, which was annoying. (I was using Claude Sonnet). I was running in Hermes agent and it would sometimes determine that the goal was impossible since there was a task assigned to humans. After the first couple days, I switch to Claude Opus 5.5, which can autonomously handle all the tasks.


Other thoughts:

Worktree pollution: Each bead spawns a whole new worktree and it doesn't cleanup very well, so after a couple days I ended up with a 300GB directory of stale worktrees. A better solution here is for there to be multiple workers each with their own worktree, doing one bead at a time. Then, git town append <bead> to create a new branch, which would allow for more efficient merging.

Agent healthiness: Tools like gas town know how to restart an agent if it ever gets stuck. That would be extremely useful here.

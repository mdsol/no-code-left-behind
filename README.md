no-code-left-behind
===================

A script to be run within an organisation to collect code from forks of ex-members

Definitions
-----------
Ex-member - a GitHub user, who was at one point a member of a GitHub Organisation, but has subsequently left
Orphaned Fork - a fork of a private repository by an Ex-member of the organisation
Mock Member - a stub account within the organisation with the intention of owning the code from the orphaned fork

Requirements Use Case
---------------------

1. A member of an organisation forks a private repository
2. The member works on their fork, adding code, fixing bugs, creating Pull Requests against the forked repository
3. The member leaves the organisation
4. The ex-member no longer has access to the fork (as it is still private), but still own the repository
5. The organisation doesn't want to lose any unmerged work  

Resolution
----------

1. Create a mock member of the organisation 
2. For each orphaned fork
	1. As the mock member, create a fork of the source repository (if the fork doesn't already exist)
	2. Clone the source repository to create a local copy  
	3. Add a remote for the orphaned fork
	4. Add a remote for the mock member fork
	5. Fetch the changes from the orphaned fork to the local repository
	6. For each (branch|tag) in the orphaned fork
		1. Create a local branch called {ex-member}\_{branch} (e.g.seeya\_master, seeya\_feature/whizzy, etc )
		2. Push the {ex-member}\_{branch} to the mock member fork
3. Delete the orphaned fork 
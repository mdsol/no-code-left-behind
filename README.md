#no-code-left-behind

A script to be run within an organisation to collect code from forks of ex-members

##Definitions
Ex-member - a GitHub user, who was at one point a member of a GitHub Organisation, but has subsequently left
Orphaned Fork - a fork of a private repository by an Ex-member of the organisation
Mock Member - a stub account within the organisation with the intention of owning the code from the orphaned fork

##Requirements Use Case

1. A member of an organisation forks a private repository
2. The member works on their fork, adding code, fixing bugs, creating Pull Requests against the forked repository
3. The member leaves the organisation
4. The ex-member no longer has access to the fork (as it is still private), but still own the repository
5. The organisation doesn't want to lose any unmerged work  

#Resolutions

##Resolution (Nuclear)

###Process
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
3. Delete the orphaned fork (as a manual action)

###Comments
1. The script is expected to be run as the mock member
  1. The login and a generated OAuth Token need to be supplied in the config/configuration.yml under the section 
  2. The deletion of the forks is to be done by the user.  A URL to the deletion element will be displayed
  3. Deletion will only be recommended when all forks are merged

##Resolution (Atomic)

###Process
As an alternative to save copying numerous numbers of (essentially) unchanged branches about, we're going to adopt a slightly different approach.
1. Get a Listing of the Branches for the Orphaned Fork.  
2. Get a Listing of the Branches for the Source repository. (cache this to disk)  
	1. Compare the list of branches and dump branches only on Orphan fork to a worklist
3. For each branch on the Orphan Repository, generate a list of the commits
4. For each branch on the Source Repository, generate a list of the commits (cache this to disk) 
	1. Compare the commits on both repositories to identify commits on Orphan that are not on Source 
5. Generate a Report showing
	1. Branches that don't exist on Source Repo
	2. Branches that exist on both, but have uncommitted changes (back to Source repo)	 
  
###Comments
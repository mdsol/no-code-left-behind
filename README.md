#no-code-left-behind

## Introduction

This repository includes a scripts for archiving code from GitHub a GitHub Fork.

## Definitions
* Ex-member - a GitHub user, who was at one point a member of a GitHub Organisation, but has subsequently left
* Orphaned Fork - a fork of a private repository by an Ex-member of the organisation
* Archive Member - a stub account within the organisation with the intention of owning the code from the orphaned fork


###Process
1. Create an archive member of the organisation
2. For each orphaned fork
	1. As the archive member, create a fork of the source repository (if the fork doesn't already exist)
	2. Clone the archive fork repository to create a local copy
	3. Add a remote for the orphaned fork
	4. Fetch the changes from the orphaned fork to the local repository
	5. For each (branch|tag) in the orphaned fork
		1. Create a local branch called {ex-member}\_{branch} (e.g.seeya\_master, seeya\_feature/whizzy, etc )
		2. Push the {ex-member}\_{branch} to the mock member fork
3. Delete the orphaned fork

###Comments
1. The script is expected to be run as the archive member (with an OAuth token for the user)
    1. The login and a generated OAuth Token need to be supplied in the config/configuration.yml under the section
    2. The deletion of the forks is to be done by the user.  A URL to the deletion element will be displayed
    3. Deletion will only be recommended when all forks are merged
2. There are a couple of problems with timing
    1. The GRIT gem adds a timeout to Git commands - this may get exhausted - I've not been able to reliably work out the timing.  In most cases running again with a longer timeout (`-t timeout`) will fix the issue

## Installation and Usage

### Installation

1. Clone
2. `bundle install`

### Usage
The `configuration.yml` file should be completed with the access details for the nominated archive user.

The script can be initiated by running 
    `$ bundle exec ruby scripts/archive_fork.rb [forks]`
the following arguments exist:
* -f {filename} - a newline separated list of forks to process
* -t {timeout} - what timeout to set for git commands


# Prints the name of the current local branch.
function git-current-branch {
    # "git branch" prints a list of local branches, the current one being marked with a "*". Extract it.
    echo "`git branch | grep '*' | sed 's/* //'`"
}

# Merge the changes from the current branch into another branch (either an existing local branch or a remote branch) and
# commit them to the remote server. After that, switch back to the original branch.
function git-svn-transplant-to {
    current_branch=`git-current-branch`
    git checkout $1 && git merge $current_branch && git svn dcommit && git checkout $current_branch
}

# Remove a remote branch from the central server. Equivalent of "svn remove <banch> && svn commit".
function git-svn-remove-branch {
    # Compute the location of the remote branches
    svnremote=`git config --list | grep "svn-remote.svn.url" | cut -d '=' -f 2`
    branches=$svnremote/`git config --list | grep branches | sed 's/.*branches=//' | sed 's/*:.*//'`
    if [ "$2" == "-f" ]; then
        # Remove the branch using svn
        svn rm "$branches$1" -m "Removing branch $1"
    else
        echo "Would remove branch $branches$1"
        echo "To actually remove the branch, use:"
        echo "  ${FUNCNAME[0]} $1 -f"
    fi
}

# Create a remote svn branch from the currently tracked one, and check it out in a new local branch.
function git-svn-create-branch {
    # Compute the location of the remote branches
    svnremote=`git config --list | grep "svn-remote.svn.url" | cut -d '=' -f 2`
    branches=$svnremote/`git config --list | grep branches | sed 's/.*branches=//' | sed 's/*:.*//'`
    destination=$branches$1
    # Determine the current remote branch (or trunk)
    current=`git svn info --url`
    if [ "$2" == "-n" ]; then
        echo " ** Dry run only ** "
        echo "svn cp $current $destination -m \"creating branch\""
        echo "git svn fetch"
        echo "git branch --track svn-$1 $1"
        echo "git checkout svn-$1"
    else
        svn cp $current $destination -m "creating branch"
        git svn fetch
        git branch --track svn-$1 $1
        git checkout svn-$1
    fi

    echo "Created branch $1 at $destination (locally svn-$1)"
}

# List the remote branches, as known locally by git.
function git-svn-branches {
    # List all known remote branches and filter out the trunk (named trunk) and the tags (which contain a / in their name)
    git branch -r | cut -d ' ' -f 3 | grep -E -v '^trunk(@.*)?$' | grep -v '/'
}

# Remove branches which no longer exist remotely from the local git references.
function git-svn-prune-branches {
    # List the real remote and locally known remote branches
    svnremote=`git config --list | grep "svn-remote.svn.url" | cut -d '=' -f 2`
    branches=$svnremote/`git config --list | grep branches | sed 's/.*branches=//' | sed 's/*:.*//'`
    remote_branches=" `svn ls $branches | sed 's/\/$//'` "
    local_branches=`git-svn-branches`

    # Check each locally known remote branch
    for branch in $local_branches; do
        found=0
        # Search it in the list of real remote branches
        for rbranch in $remote_branches; do
            if [[ $branch == $rbranch ]]; then
                  found=1
            fi
        done
        # If not found, remove it
        if [[ $found == 0 ]]; then
            if [[ "$1" == "-f" ]]; then
                git branch -r -D $branch
            else
                echo "Would remove $branch"
            fi
        fi
    done

    # If this was only a dry run, indicate how to actually prune
    if [[ "$1" != "-f" ]]; then
        echo "To actually prune branches, use:"
        echo "  ${FUNCNAME[0]} -f"
    fi
}

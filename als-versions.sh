#!/bin/bash
# Script for setting up, updating & merging an Ableton Live .als (an XML based file, gzip'd with a .als extension) project folder with Git version controlling
# Written by Colin Patrick McArdell 2011
# colin@colinmcardell.com
# 
GITDIRECTORY=".git"
FILETYPE=".als"
FILES=`ls | grep "$FILETYPE"`

usage () {
	echo "usage: alsversions <subcommand>"
	echo
	echo "Available subcommands are:"
	echo "   -c        + filename to compress file."
	echo "   -d        + filename to decompress gzip'd file."
	echo "   -m        + branchname to merge with master branch."
	echo "   -s        sets up a project folder to be used with git."
	echo "   -u        update git repo, if git repo no setup then setup."
	echo
}

# Get the file type
getCurrentFileType () {
	currentFileType=`file "$1" | awk '{ print $2 }'` # Gets the file type.
}

# Get current branch
getCurrentBranch () {
	currentBranch=`git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/\*//'`
	echo "The current branch is "$currentBranch"."
}

# Decompress file if necessary/possible.
decompress () {
	#file "$1" | awk -F: ' /gzip/{print $1}'` # Outputs the files that are gzip files
	getCurrentFileType $1
	echo "Checking if file(s) of type \"$FILETYPE\" need to be decompressed."
	if [ "$currentFileType" == "gzip" ]; then
		echo "File \"$1\" of type \"$currentFileType\" will be decompressed."
		for a in "$1"
			do
				NAME="${a%.*}"
				EXT="${a#*.}"
				echo "------------------------"
				echo "gunzipping \"$a\" to \"${a%.*}-decompressed.${a#*.}\"."
				gunzip -c -S "$FILETYPE" "$a" > "${a%.*}"-decompressed."${a#*.}"
				echo "Removing \"$a\"."
				rm "$a"
				echo "Moving decompressed file to \"$a\"."
				mv "${a%.*}"-decompressed."${a#*.}" "$a"
		done;
		echo "---"
	else
		echo "File \"$1\" is of type \"$currentFileType\" and won't be decompressed."
		echo "---"
	fi;
}

# Compress file if necessary/possible.
compress () {
	getCurrentFileType $1
	echo "You have requested that file \"$1\" of type \"$currentFileType\" be compressed."
	if [ "$currentFileType" != "gzip" ]; then # Check to make sure the file is not already gzip'd
		for a in "$1"
			do
				NAME="${a%.*}"
				EXT="${a#*.}"
				echo "------------------------"
				echo "Moving \"$a\" to \"$NAME\"."
				mv $a $NAME
				echo "gzipping \"$NAME\" to \"$a\"."
				gzip -9 -S "$FILETYPE" "$NAME"
		done;
	else # If file is already gzip'd report back and don't effect file.
		echo "File \"$1\" is a gzip'd file and won't be re-compressed."
	fi;
}

# Stage and commit all changed files with User input for commit comment.
stageAndCommit () {
	gitrm=`git ls-files --deleted`
	gitst=`git status -s`
	gitRemoveDeleted () {
		if [ ! -z "$gitrm" ]; then
			echo "Would you like to remove the following files from your project?:"
			echo "$gitrm"
			echo "(y/n) then [ ENTER ]"
			read REMOVE
			while [ "$REMOVE" != "y" ] && [ "$REMOVE" != "n" ]; do
				echo "$REMOVE"
				echo "Option not valid."
				echo "Would you like to remove the following files from your project?:"
				echo "$gitrm"
				echo "(y/n) then [ ENTER ]"
				read REMOVE
			done
			if [ "$REMOVE" == "y" ]; then
				echo "Removing the following files from this project:"
				for a in "$gitrm"
					do
						git rm $a
				done;
			else
				echo "Not removing these files from this project..."
				echo "$gitrm"
			fi;
		fi;
	}
	gitAddChanged () {
		if [ ! -z "$gitst" ]; then
			echo "Staging all changed files:"
			echo "$gitst"
			echo "---"
			git add .
		fi;
	}
	gitRemoveDeleted
	gitAddChanged
	if [ ! -z "$gitst" ]; then
		echo "Please enter a description of the changes that you have made in this commit, then press [ ENTER ]."
		read COMMENT
		git commit -m "$COMMENT";
	else
		echo "There have been no changes to this project since the last commit. Get to work!"
	fi;
}

setup () {
	# Check if there is a .git folder, indicating if there has been a git repo setup.
	if [ -d "$GITDIRECTORY" ]; then
		echo "Git has already been setup for this project, please use -u to update the repo."
	else
		echo "Setting up Git for this project."
		git init
		echo "*.als -text crlf diff" > .gitattributes
		decompress "$FILES"
		stageAndCommit;
	fi;
}

# Update (or setup) Git repo.
update () {
	# Check if there is a .git folder, indicating if there has been a git repo setup.
	if [ -d "$GITDIRECTORY" ]; then
		decompress "$FILES"
		stageAndCommit
	else
		setup
	fi;
}

# Git merge specified branch with current branch
merge () {
	# Check if there is a .git folder, indicating if there has been a git repo setup.
	if [ -d "$GITDIRECTORY" ]; then
		getCurrentBranch
		if [ "$currentBranch" == "master" ]; then
			decompress "$FILES"
			stageAndCommit
			git merge $1
			echo ""$1" has been merged with the master branch."
			echo "Would you like to clean up by removing the branch "$1" now that it has been merged?"
		else
			decompress "$FILES"
			stageAndCommit
			git checkout master
			git merge $1
			echo ""$1" has been merged with the master branch."
			echo "Would you like to clean up by removing the branch "$1" now that it has been merged?"
		fi
	else
		echo "Git has not been setup for this project."
		setup
	fi;
}

# Options for execution of script.
while getopts ":c:d:m:hsu" optname
	do
		case "$optname" in
			"h")
				usage
				exit 1
				;;
			"c")
				echo "Compressing $OPTARG"
				echo "---"
				compress "$OPTARG"
				;;
			"d")
				echo "Decompressing $OPTARG"
				echo "---"
				decompress "$OPTARG"
				;;
			"m")
				echo "You have requested to merge $OPTARG with the master branch."
				echo "---"
				merge "$OPTARG"
				;;
			"u")
				echo "You have requested to update the git repo."
				echo "---"
				update
				;;
			"s")
					echo "Setting up git repo."
					echo "---"
					setup
					;;
			"?")
				echo "Unknown option $OPTARG"
				usage
				exit 1
				;;
			":")
				echo "No argument value for option $OPTARG"
				;;
			*)
			# Should not occur
				echo "Unknown error while processing options"
				;;
		esac
	done

#!/bin/bash

# Install Ubuntu packages
apt-get update
apt-get install -y clang-format-3.9 git

# Function to apply clang-format
# according to docs, the --style=file will find the .clang-file at the root placed by the Dockerfile copy
# https://releases.llvm.org/10.0.0/tools/clang/docs/ClangFormat.html
# Use -style=file to load style configuration from
#                              .clang-format file located in one of the parent
#                              directories of the source file (or current
#                              directory for stdin).
apply_style(){
  find . -name '*.h' -or -name '*.hpp' -or -name '*.cpp' | xargs clang-format-3.9 -i -style=file $1
}

# Process script inputs
echo
echo "================================="
echo "Processing action input arguments"
echo "================================="
name=$1
email=$2
message_title=$3
if [[ $4 == 'check-only' ]]; then
  do_commit=0
  echo "Action input 'check-only-or-commit' set to 'check-only': formatting and failing in case code is not properly formatted"
elif [[ $4 == 'commit' ]]; then
  do_commit=1
  echo "Action input 'check-only-or-commit' set to 'commit': formatting and, if necessary, committing and pushing code to the repository with:
- Author name: $name
- Author email: $email
- Commit message title: '$message_title'"
else
  echo "Action input 'check-only-or-commit' takes either of the following arguments: ['check-only', 'commit']!"
  echo "Exiting"
  exit 1
fi

# Git configuration
git config --global --add safe.directory /github/workspace
git config --global user.name "$name"
git config --global user.email "$email"
git config --global push.default current

# Apply clang-format
echo
echo "======================="
echo "Applying style to files"
echo "======================="
apply_style

# Determine modified files using Git
modified_files=$(git diff --name-only | xargs)
exit_code=$?

# If last command was executed successfully (exit status 0): check modified files (do_commit=0) or commit and push modified files (if do_commit=1)
if [[ $exit_code == 0 ]]; then
  if [[ $modified_files ]]; then
    message_mod_files="Modified files:"
    read -ramod_files<<< "$modified_files"
    for file in "${mod_files[@]}"; do
      message_mod_files+="
- $file"
    done

    echo "$message_mod_files"

    if [[ $do_commit -eq 0 ]]; then
      echo
      echo "Files modified after formatting"
      echo "Please format code before pushing to the repository"
      echo "CHECK FAILED"
      exit 1

    elif [[ $do_commit -eq 1 ]]; then
      echo
      echo "============================"
      echo "Committing to current branch"
      echo "============================"

      git commit -a -m "$message_title" -m "$message_mod_files"
      git push
    fi

  else
    echo
    echo "No modified files after formatting"
    echo "CHECK PASSED"
    exit 0
  fi

# If last command failed (exit status != 0): print error message and exit
else
  echo "Running command 'modified_files=\$(git diff --name-only | xargs)' was not successful and exited with code $exit_code!"
  echo "Exiting"
  exit $exit_code
fi

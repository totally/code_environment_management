#!/bin/bash

# Exit on failures
set -e 

USAGE="                                                                         \n
    Script to create/destroy code environments                                  \n
                                                                                \n
    Given environment name, script creates a git branch by that name, and       \n
    clones the repo to a local directory.  This is useful for webapp envs       \n
    that can be dynamically created.  Just wildcard (*) dns for                 \n
    *.the code.domain.com, then use mod_alias to lookup the ServerRoot          \n
    dynamically.                                                                \n
                                                                                \n
    $0 <-t code> <-e envornment_name> <-c|-d>                                   \n
                                                                                \n
    -t  type        type of environment, code is only one currently supported   \n
    -e  env name    the name of your new environment                            \n
    -c  create      create a new environment (creates new branch and checks     \n
                    it out.                                                     \n
    -d destroy      destroys local checkout and the branch on origin            \n
                                                                                \n
                                                                                \n
    Example:                                                                    \n
        agile_code.sh -c -t code -e foo     # Creates environment foo           \n
        agile_code.sh -d -t code -e foo     # Destroys environment foo          \n
"
send_usage() {
        echo -e $USAGE
}
error_usage() {
        send_usage
        exit 1
}

GIT_REPO=git@github.com:YOUR_USERNAME/YOUR_REPONAME.git
DOMAIN=YOUR_DOMAIN.com
WEBROOT=/var/www/agile

# If repo doesn't need to be group editable, set to 022/755
# We manually chmod the repo dir because older versions of
# git are hardcoded to set it to 755
UMASK=002
CHMOD=775

# Process command line opts
while getopts "cdphe:t:" OPTION
do
     case $OPTION in
         h)
             send_usage
             exit 1
             ;;
         d)
            DELETE_BRANCH=true
            ;;
         c)
            CREATE_BRANCH=true
            ;;
         e)
            # Only proceed if environment is alphanumeric
            if [[ ! $OPTARG =~ ^[A-Za-z0-9]*$ ]]; then
                echo "ERROR: Environment name must be alphanumeric!"
                exit 1
            fi
             ENV=$OPTARG
             echo "Got environment: [$ENV]"
             ;;
         t)
            # only -t(ype) supported is "code", but you can add more (eg. test)
            case $OPTARG in
            code)
                TYPE=$OPTARG
                echo "type is [$TYPE]"
                ;;
            *)
                echo "ERROR: Unknown type [$OPTARG]"
                exit 2
                ;;
            esac
            ;;
         ?)
             send_usage
             exit
             ;;
     esac
done


# ---------------
# SANITY CHECK
# ---------------
if [[ "$DELETE_BRANCH" == "true" ]] && [[ "$CREATE_BRANCH" == "true" ]]; then
    echo "ERROR: can't delete and create branch.  Pick one"
    error_usage
fi
if [ "$TYPE" != "code" ]
then
    echo "Unknown environment type: [${TYPE}]"
    error_usage 
    LOCAL_DIR=${WEBROOT}/${ENV}.${DOMAIN}
fi

# ---------------
# LOCAL_DIR
# ---------------
LOCAL_DIR=${WEBROOT}/${ENV}.${TYPE}.${DOMAIN}
echo "Working dir is [$LOCAL_DIR]"

# ------------------
# BIRTH
# ------------------
create_and_checkout_branch () {
    echo "Cloning and creating branch [$ENV]"
    umask $UMASK
    git clone $GIT_REPO $LOCAL_DIR
    # Change perm from 755 to 775
    chmod $CHMOD $LOCAL_DIR
    cd $LOCAL_DIR
    echo "Creating branch $ENV"
    git checkout -b $ENV
    git push origin $ENV
}
    

checkout_existing_branch () {
    echo "Cloning existing branch [$ENV]"
    git clone $GIT_REPO -b $ENV $LOCAL_DIR
    chmod $CHMOD $LOCAL_DIR
}


# ------------------
# DEATH
# ------------------
delete_branch () {
    if [ ! -d $LOCAL_DIR ]
    then
        echo "Directory does not exist!"
        #exit 1
    else
        cd $LOCAL_DIR
        git push origin :$ENV
    fi
}

delete_checkout () {
    echo "Removing checkout"
    if [ ! -d $LOCAL_DIR ]
    then
        echo "Directory does not exist!"
        #exit 1
    else
        rm -rf $LOCAL_DIR
    fi
}

## ------------------
## Run it...
## ------------------
if [ "$DELETE_BRANCH" == "true" ]
then
    # Test delete will only delete the checkout
    if [ "$TYPE" == "code" ]
    then
        delete_branch
    fi
    delete_checkout
fi

if [ "$CREATE_BRANCH" == "true" ]
then
    # Test checks out existing repo, code creates new repo
    if [ "$TYPE" == "code" ]
    then
        create_and_checkout_branch
    else
        checkout_existing_branch
    fi
fi


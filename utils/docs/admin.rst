.. _admin-page:

*******************
Admin
*******************

Generate preload cache with default values

::

   git_repo_url=http://myGitRepoUrl
   git_repo_name="myGitRepoName"
   git clone ${git_repo_url}
   mkdir build
   cd build ../${git_repo_name}/utils/cmake/initCmakePreload.sh ../${git_repo_name}



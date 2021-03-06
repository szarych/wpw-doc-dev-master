#!/bin/bash

# Copyright (c) 2016-2017 Martin Donath <martin.donath@squidfunk.com>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

# Exit, if one command fails
set -e

# Run build and terminate on error
"$(yarn bin)"/gulp build --clean --optimize --revision --no-lint

# Deploy documentation to GitHub pages
if [ "$TRAVIS_BRANCH" == "master" -a "$TRAVIS_PULL_REQUEST" == "false" ]; then
  REMOTE="https://${GH_TOKEN}@github.com/szarych/wpw-doc-dev-master"

  # Set configuration for repository and deploy documentation
  git config --global user.name "${GH_NAME}"
  git config --global user.email "${GH_EMAIL}"
  git remote set-url origin $REMOTE
  mkdocs gh-deploy --force
fi

# Terminate if we're not on a release branch
echo "$TRAVIS_BRANCH" | grep -qvE "^[0-9.]+$" && exit 0; :;

# Install dependencies for release build
pip install --user wheel twine

# Build and install theme and Docker image
python setup.py build sdist bdist_wheel --universal
docker build -t $TRAVIS_REPO_SLUG .

# Prepare build regression test
pushd /tmp
mkdocs new test && cd test
echo "theme: worldpay" >> mkdocs.yml

# Test Docker image build
docker run --rm -it -v `pwd`:/docs $TRAVIS_REPO_SLUG build

# Return to original directory
popd

# Push release to PyPI
twine upload -u $PYPI_USERNAME -p $PYPI_PASSWORD dist/*

# Push image to Docker Hub
docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
docker tag $TRAVIS_REPO_SLUG $TRAVIS_REPO_SLUG:$TRAVIS_BRANCH
docker tag $TRAVIS_REPO_SLUG $TRAVIS_REPO_SLUG:latest
docker push $TRAVIS_REPO_SLUG

TissueMAPS benchmark tests
==========================


Requirements
------------

Tests will be controlled from a local machine, which will interact with remote servers running in the cloud over the internet (using *SSH* for deployment and *HTTP* for performing the actual tests).

#### Operating system

The controlling machine should be *UNIX* based, i.e. either *MacOSX* or *Linux*, mainly because [Ansible](https://docs.ansible.com/ansible/), which we use to deploy *TissueMAPS* on the remote servers, doesn't run on *Windows* (see [Ansible docs](https://docs.ansible.com/ansible/intro_windows.html#using-a-windows-control-machine) for details).

#### Software

The controlling machine further needs to have [Python](https://www.python.org/) installed (both Python 2 and 3 are supported) as well as its package manager [pip](https://pip.pypa.io/en/stable/).

In addition, it needs [OpenSSH](https://www.openssh.com/), [OpenSSL](https://www.openssl.org/) and the [GCC](https://gcc.gnu.org/>) compiler.

Install the [tmdeploy](https://pypi.python.org/pypi/tmdeploy) and [tmclient](https://pypi.python.org/pypi/tmclient) Python packages from PyPi. For this, you can use a [Python virtual environment](https://virtualenv.pypa.io/en/stable/):

    $ pip install virtualenv
    $ virtualenv ~/.envs/tmaps
    $ source ~/.envs/tmaps/bin/activate

    $ pip install tmdeploy tmclient

#### Data

You will need a dataset to run the tests against. We are working on making datasets publicly available.


#### Installation for CentOS-7 Linux distribution

Install system packages as `root` user:

    $ yum update
    $ yum install -y git gcc epel-release openssl-devel python-devel python-setuptools python-pip

    $ pip install -U pip setuptools

Install Python packages as non-privilaged user:

    $ pip install --user tmclient tmdeploy


Deploying servers in the cloud
------------------------------

Clone this repository:

    $ git clone https://github.com/tissuemaps/tmbenchmarks ~/tmbenchmarks

Specify, which of the architectures you would like to set up and run the tests against. To this end, pick one of the setup files for one of the architectures, for example ``cluster-32`` to build a small cluster with 32 CPU cores for compute resources.

Use the ``tm_deploy`` command line tool to launch the servers in the cloud:

    $ tm_deploy -vv vm -s ~/tmbenchmarks/setup/cluster-32.yml launch

and deploy the *TissueMAPS* application:

    $ tm_deploy -vv vm -s ~/tmbenchmarks/setup/cluster-32.yml deploy

Running tests
-------------

Once the required infrastructure has been provisioned and the software deployed, you can run the test:

    $ ~/tmbenchmarks/start_test.sh $HOST

where ``HOST`` is the public IP address of the cloud virtual machine that hosts the *TissueMAPS* web server.

You can use the ``tm_inventory`` command line tool to list metadata about machines that have been set up in the cloud (including their IP addresses):

    $ tm_inventory --list

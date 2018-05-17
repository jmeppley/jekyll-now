---
layout: post
---

I have been using jupyter notebooks since just before project jupyter launched,
back when they were still called ipython notebooks. I recommend this type of
workspace for anyone doing exploratory bioinformatics. When combined with
version control (or even Dropbox.com) you get a history of all your work. 
 
I find it invaluable for when someone asks me to go back to some one-off
project from two years ago. "Hey, you remember that plot we made in 2015? I want
to do that again with this new experiment." Even if you're not great about
documenting everything you do, you'll still have all your work saved in an easy
to view web page.

I am constanly trying to imprpove my working habits, but I also recognize that
I'm never going to complete that process, so it is a good idea to also use
techlogy as a fall back.

Notebooks are great because they make it really easy to keep human readable
notes as you go, but it they also save your commands incase you don't comment
well.

## Today's problem

The project jupyter team is moving at a pace that makes it hard to keep up.
This is a good thing, but I recently took the leap into JupyterHub and
JupyterLab simultaneusly. 

There are a some features in Lab and Hub that prompted me to switch:

 * always on access without ssh tunnels to our firelwalled servers (Hub)
 * easier access from a tablet (for when I take my wife's Yoga Book)
 * interactive visualizations (with Lab and Altair 2.0)
 * easier support for other folks in my group (Hub)

Meanwhile, I have a few requirements that I want to carry over from my existing
jupyter setup:

 * multiple conda envs
 * vim binding for notebooks
 * other juptyer extensions

### Jupyter Hub
Jupyter Hub is a web server that runs in the background allowing any user with
command line access to launch and access their own jupyter notebook server.

#### Certificates

The first order of business is to set get a certificat for your JupyterHub
server so you can access via HTTPS. This is not STRICTLY necessary, but is
highly recommended if you are going to open it up to the world (not behind a
firewall)

I follwed the [directions
here](https://gist.github.com/jchandra74/36d5f8d0e11960dd8f80260801109ab0).

#### conda environment
I use [conda](https://conda.io/miniconda.html) as much as possible to install software these days. It just makes
life easier. I highly reccomend it. The following assumes it's already
installed.

Create a conda env:

```bash
# always use conda-forge
conda config --append channels conda
# the base jupyterhub packages
conda conda create -n jupyter python=3 ipython ipykernel jupyterhub notebook
suodospawner
# activate
conda activate jupyter

# extensions make life better
conda install jupyter_contrib_nbextensions
conda install -c anaconda-nb-extensions anaconda-nb-extensions

# to enable jupyterlab
conda install jupyterlab

# vim in jupyterlab
jupyter labextension install jupyterlab_vim
```

#### jupyter user

I set up a user named jupyter to run the server (following the [instructions
here](https://github.com/jupyterhub/jupyterhub/wiki/Using-sudo-to-run-JupyterHub-without-root-privileges)):

#### Create user

```bash
useradd -r  -M -u 501 jupyter
groupadd -g 502 jupyterhub
conda install -c conda-forge sudospawner
```

#### Add only necessary authority
I added the following to the /etc/sudoers using `visudo` to let the jupyter
user spawn things as other users:
```
# the command(s) the Hub can run on behalf of the above users without needing a
password
# the exact path may differ, depending on how sudospawner was installed
Cmnd_Alias JUPYTER_CMD = /opt/miniconda/envs/jupyter/bin/sudospawner

# give the Hub user permission to run the above command on behalf
# of the any users in jupyterhub group without prompting for a password
jupyter ALL=(%jupyterhub) NOPASSWD:JUPYTER_CMD
```

Give jupyter user acces to the shadow file using the shadow group. It needs
this to verify passwords.
 ```bash
 ls -l /etc/shadow
 groupadd shadow
 chgrp shadow /etc/shadow
 chmod g+r /etc/shadow
 ls -l /etc/shadow
 ```

I want jupyterhub to listen on the default HTTPS port 443, so the jupyter user needs privileged port access. We limit it to just the necessary programs.
```
(jupyter) root@hostname:~# which node
/opt/miniconda/envs/jupyter/bin/node
(jupyter) root@hostname:~# ls -l `which configurable-http-proxy`
lrwxrwxrwx 1 root root 71 Apr 30 07:35
/opt/miniconda/envs/jupyter/bin/configurable-http-proxy ->
../lib/node_modules/configurable-http-proxy/bin/configurable-http-proxy
(jupyter) root@hostname:~# setcap 'cap_net_bind_service=+ep' /opt/miniconda/envs/jupyter/bin/node
(jupyter) root@hostname:~# setcap 'cap_net_bind_service=+ep' /opt/miniconda/envs/jupyter/lib/node_modules/configurable-http-proxy/bin/configurable-http-proxy
(jupyter) root@hostname:~# chgrp jupyter /opt/miniconda/envs/jupyter/bin/node /opt/miniconda/envs/jupyter/lib/node_modules/configurable-http-proxy/bin/configurable-http-proxy
(jupyter) root@hostname:~# chmod o-x /opt/miniconda/envs/jupyter/bin/node /opt/miniconda/envs/jupyter/lib/node_modules/configurable-http-proxy/bin/configurable-http-proxy
(jupyter) root@hostname:~# chmod go-w /opt/miniconda/envs/jupyter/bin/node /opt/miniconda/envs/jupyter/lib/node_modules/configurable-http-proxy/bin/configurable-http-proxy
```

This lets the jupyter user run the server software at the heart of JupyterHub.

#### Enable Users
I add my user to the JupyterHub to the jupyterhub group so that I can access the Hub:
```
sudo usermod -a -G jupyterhub jmeppley
```

This must be done for any users wishing to access the server.


#### Run
I created a simple launch script to run as jupyter:
```bash
export PATH=/opt/miniconda/bin:$PATH
source activate /opt/miniconda/envs/jupyter

jupyterhub --JupyterHub.spawner_class=sudospawner.SudoSpawner --ip hostname.domain  --port 443 --ssl-key certs/hub.key --ssl-cert certs/hub.crt.pem
```

NOTE: Even though the latest conda has moved to `conda activate` from `source activate`, JupyterLab currently doesn't work properly using that paradigm. It failed to interface with conda, so the registered kernels are not available. To work wround this, I fall back to the classic conda invocation in the above script.

Just make sure the script is executable and you're all set. Jupyter Hub will set up a proxy server on port 443 that communicates with the actual notebook servers, so only port 443 needs to be visible to the outside world.

### User side setup
We have a working jupyter hub and lab server, but I still want my custom environments. To do this, I need to create and activate my own environment (as my personal account, not root or jupyter) and then do the following:

##### Install some necessary packages
The conda env must have the ipykernel package and the conda notebook extensions from continuumIO. Only the first is necessary to pick up the python environment, but if you want the execution path to match, you need the other two:

```
conda install -c anaconda-nb-extensions -c conda-forge nb_conda nb_conda_kernels ipykernel
```

##### Register the kernel
```bash
python -m ipykernel install --user --name myenv --display-name "Python (myenv)"
```
(Make sure you change the env name!)

## That's it!
Now I have a working JupyterHub server that I can log into with my personal credentials.

If I want to access JupyterHub instead of the original notebook server, I replace /tree with /lab at the end of the URL. 

### Left To Do
There are a few steps left to make it a perfect set up:

 * Set up JupyterHub as a service that will launch at startup
 * Set up JupyterLab to be the default in JupyterHub


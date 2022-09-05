FROM hlsong/pytorch:1.12.0-py3.8-cuda11.3.1-runtime-ubuntu20.04
################################
# Install apt-get Requirements #
################################
ENV LANG C.UTF-8
ENV APT_INSTALL="apt-get install -y --no-install-recommends"
ENV PIP_INSTALL="python -m pip --no-cache-dir install --upgrade --default-timeout 100"

RUN sed -i "s/archive.ubuntu.com/mirrors.ustc.edu.cn/g" /etc/apt/sources.list && \
    rm -rf /var/lib/apt/lists/* \
    /etc/apt/sources.list.d/cuda.list \
    /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get update
RUN DEBIAN_FRONTEND=noninteractive $APT_INSTALL \
    apt-utils build-essential ca-certificates cifs-utils cmake curl dpkg-dev g++ 
RUN DEBIAN_FRONTEND=noninteractive $APT_INSTALL \
    git htop rar sudo swig tar tmux tzdata unrar unzip vim wget xvfb zip zsh software-properties-common
RUN DEBIAN_FRONTEND=noninteractive $APT_INSTALL \
    x11vnc xpra xserver-xorg-dev iproute2 iputils-ping locales mesa-utils net-tools qt5-default
RUN DEBIAN_FRONTEND=noninteractive $APT_INSTALL \
    nfs-common openmpi-bin openmpi-doc openssh-client openssh-server openssl patchelf pkg-config 
RUN DEBIAN_FRONTEND=noninteractive $APT_INSTALL \
    libboost-all-dev libdirectfb-dev libevent-dev libgl1-mesa-dev libgl1-mesa-glx libglew-dev libglfw3 \
    libglib2.0-0 libncurses5-dev libncursesw5-dev libopenmpi-dev libosmesa6-dev libsdl2-dev libsdl2-gfx-dev \ 
    libsdl2-image-dev libsdl2-ttf-dev libsm6 libst-dev libxext6 libxrender-dev 
#########
# NVTOP #
#########
RUN git clone https://github.com/Syllo/nvtop.git && cd nvtop \
    && mkdir build && cd build \
    && cmake .. && make && make install \
    && cd ../.. && rm -rf nvtop
# ++++++++++++++++++++++++++++
# change conda & pip sources #
# ++++++++++++++++++++++++++++
RUN conda config --add channels https://mirrors.ustc.edu.cn/anaconda/cloud/conda-forge/ && \
    conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/main/ && \
    conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/free/ && \
    conda config --add channels https://mirrors.ustc.edu.cn/anaconda/cloud/menpo/ && \
    conda config --add channels https://mirrors.ustc.edu.cn/anaconda/cloud/bioconda/ && \
    conda config --add channels https://mirrors.ustc.edu.cn/anaconda/cloud/msys2/ && \
    conda config --set show_channel_urls yes 

RUN ${PIP_INSTALL} -i https://mirrors.ustc.edu.cn/pypi/web/simple pip -U && \
    pip config set global.index-url https://mirrors.ustc.edu.cn/pypi/web/simple
###################
# zsh & tmux #
###################
ENV SHELL /bin/zsh
RUN git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh && \
    cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc && \
    sed -i "s/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"ys\"/g" ~/.zshrc && \
    sed -i "s/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting tmux)/g" ~/.zshrc && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone https://github.com/gpakosz/.tmux.git && \
    ln -s -f .tmux/.tmux.conf && \
    cp .tmux/.tmux.conf.local . &&\
    /opt/conda/bin/conda init zsh &&\
    chsh -s /bin/zsh 
################
# Set Timezone #
################
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8 && \
    echo "Asia/Shanghai" > /etc/timezone && \
    rm -f /etc/localtime && \
    rm -rf /usr/share/zoneinfo/UTC && \
    dpkg-reconfigure --frontend=noninteractive tzdata
#################
#   Set Shell    # 
#################
RUN echo "if [ -t 1 ]; then" >> /root/.bashrc
RUN echo "exec zsh" >> /root/.bashrc
RUN echo "fi" >> /root/.bashrc

RUN conda update --all -y 
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

###################
# python packages #
####################
RUN conda install ruamel.yaml conda -y
RUN conda install -c conda-forge -y \
    scikit-learn scikit-video \
    gym tensorboard tensorboardX pandas seaborn matplotlib
RUN ${PIP_INSTALL} scikit-image termcolor wandb hydra-core kornia git+https://github.com/oxwhirl/smac.git gfootball mujoco mujoco-py 
#############
# MARL ENVS #
#############
WORKDIR /marl_envs
ADD *.tar.gz ./
ADD *.zip ./
# StarCraftII #
RUN unzip -P iagreetotheeula SC2.4.10.zip && \
    mkdir -p StarCraftII/Maps/ && \
    unzip SMAC_Maps.zip && mv SMAC_Maps StarCraftII/Maps/ && \
    rm -rf SC2.4.10.zip && rm -rf SMAC_Maps.zip && rm -rf __MACOSX/ 
ENV SC2PATH /marl_envs/StarCraftII
# Bi-DexHands 
RUN ${PIP_INSTALL} -e ./isaacgym/python
RUN unzip IsaacGymEnvs.zip && rm -rf IsaacGymEnvs.zip && \
    ${PIP_INSTALL} -e ./IsaacGymEnvs
# Multi-Agent Mujoco 
RUN mkdir -p /root/.mujoco && cp -r mujoco210 /root/.mujoco/ && rm -rf mujoco210
RUN unzip multiagent_mujoco.zip && rm -rf multiagent_mujoco.zip && \
    ${PIP_INSTALL} -e ./multiagent_mujoco
ENV LD_LIBRARY_PATH /root/.mujoco/mujoco210/bin:$LD_LIBRARY_PATH
ENV LD_PRELOAD /usr/lib/x86_64-linux-gnu/libGLEW.so
# # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

##################
# Apt auto clean #
##################
RUN ldconfig && \
    conda clean -y -all && \
    apt-get clean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /root/.cache/pip
WORKDIR /home
EXPOSE 6006
ENTRYPOINT ["zsh"]
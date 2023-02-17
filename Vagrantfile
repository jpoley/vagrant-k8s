IMAGE_NAME = "bento/ubuntu-20.04"
N = 2

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false

    config.vm.provider "virtualbox" do |v|
        v.memory = 5000 
        v.cpus = 2
    end
      
    config.vm.define "k8s-master" do |master|
        master.vm.box = IMAGE_NAME
        master.vm.network "private_network", ip: "192.168.56.10"
        master.vm.hostname = "k8s-master"
        master.vm.provision :shell, path: "scripts/apt.sh", run: 'always', privileged: true
        master.vm.provision :shell, path: "scripts/126.sh", run: 'always', privileged: true
        master.vm.provision :shell, path: "scripts/1262.sh", run: 'always', privileged: true
        master.vm.provision :shell, path: "scripts/install-trivy.sh", run: 'always', privileged: true
        master.vm.provision :shell, path: "scripts/install-falco.sh", run: 'always', privileged: true
    	master.vm.provision "file", source: "./kubernetes-setup/kube-flannel.yaml", destination: "kube-flannel.yaml"
        master.vm.provision "file", source: "./kubernetes-setup/calico.yaml", destination: "calico.yaml"
        master.vm.provision "file", source: "./kubernetes-setup/tigera-operator.yaml", destination: "tigera-operator.yaml"
        master.vm.provision "file", source: "./kubernetes-setup/custom-resources.yaml", destination: "custom-resources.yaml"
        master.vm.provision "file", source: "./scripts/good-k8s-bash.sh", destination: "good-k8s-bash.sh"
        master.vm.provision "file", source: "./kubernetes-setup/get-etcdctl.sh", destination: "get-etcdctl.sh"
        master.vm.synced_folder "yaml/",  "/home/vagrant/yaml/"
        master.vm.synced_folder "scripts/",  "/home/vagrant/scripts/"
        master.vm.synced_folder "kubernetes-setup/",  "/home/vagrant/kubernetes-setup/"
        master.vm.provision :shell, path: "scripts/c.sh", run: 'always', privileged: true
        master.vm.provision "ansible" do |ansible|
            ansible.playbook = "kubernetes-setup/master-playbook.yml"
        end
    end

    (1..N).each do |i|
        config.vm.define "node-#{i}" do |node|
            node.vm.box = IMAGE_NAME
            node.vm.network "private_network", ip: "192.168.56.#{i + 10}"
            node.vm.hostname = "node-#{i}"
            node.vm.provision :shell, path: "scripts/126.sh", run: 'always', privileged: true
            node.vm.provision :shell, path: "scripts/1262.sh", run: 'always', privileged: true
            node.vm.provision "ansible" do |ansible|
                ansible.playbook = "kubernetes-setup/node-playbook.yml"
            end
        end
    end
end

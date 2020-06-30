# MPTP Tutorial Hands-On

## VM Setup

Just run the following commands

```bash
$ vagrant up
$ vagrant ssh
```

and you will be connected to the VM.

## 1. Observing the Bandwidth Aggregation when Using Multiple Paths

One of the use cases of multipath transport protocols is to aggregate the bandwidths of the available paths.
To demonstrate this, let's consider a simple, symmetrical network scenario.

   |-------- 20 Mbps, 40 ms RTT ---------|
Client                                Router --------- Server
   |-------- 20 Mbps, 40 ms RTT ---------|

This scenario is described in the file `tutorial_files/01_multipath/topo`.
With this network, we will compare two `iperf` runs.
The first consists in a regular TCP transfer between the client and the server.
To perform this experiment, `ssh` into the vagrant VM using
```bash
$ vagrant ssh
```
And then type the following
```bash
$ cd /vagrant_data/tutorial_files/01_multipath
$ sudo python ~/minitopo2/runner.py -t topo -x xp_tcp
```
The run will take about 25 seconds.
When done, you can check on the VM the content of `ìperf.log` using
```bash
$ cat iperf.log
```
You should notice that the goodput achieved by `ìperf` should be about 19-20 Mbps, which is expected since only one of the 20 Mbps network path is used.
The run should also provide you two pcap files, one from the client's perspective and the other from the server's one.

Then, we will consider the same experiment, but running now Multipath TCP instead of plain TCP.
For this, in the vagrant VM, just type the following command in the VM.
```bash
$ sudo python ~/minitopo2/runner.py -t topo -x xp_mptcp
```
A quick inspection of the `iperf.log` file should indicate a goodput twice larger than with plain TCP.
This confirms that Multipath TCP can take advantage of multiple network paths (in this case, two) while TCP cannot.

## 2. Impact of Using Multiple Paths
- Impact of the traffic (http size)
- Impact of the scheduler

## 3. Impact of the Path Manager
- fullmesh
- ndiffports
- binder?

## 4. The notion of Backup Path
- Experiment with lost first path, second one backup

## 5. The impact of the Congestion Control Algorithm
- coupled
- cubic
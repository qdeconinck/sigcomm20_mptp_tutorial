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

## 2. Impact of the Selection of the Path

The packet scheduler is one of the multipath-specific algorithms.
It selects on which available subflow for sending the next packet will be sent.
The two most basic packets schedulers are the following.

* Lowest RTT first: called `default` in MPTCP, it favors the available subflow experiencing the lowest RTT.
* Round-Robin: called `roundrobin` in MPTCP, it equally shares the network load across subflows.

The packet scheduler is also responsible of the content of the data to be sent.
Yet, due to implementation constraints, most of the proposed packet schedulers in the litterature focus on the first data to be sent (i.e., they only select the path where to send the next data).
With such strategy, the scheduler has only impactful choices when several network paths are available.

Case 1: MSG traffic from client perspective

Case 2: HTTP traffic

wget returns the following results (in seconds)

|**GET Size** | 256 KB | 1 MB  | 10 MB |
|**Scheduler**|--------|-------|-------|
| Lowest RTT  | 0.286  | 0.576 |
| Round Robin | 0.285  | 0.597 |


To demonstrate this, we consider 

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
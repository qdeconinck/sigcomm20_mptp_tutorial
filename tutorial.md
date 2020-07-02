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


### Case 1: MSG traffic from client perspective

   |-------- 100 Mbps, 40 ms RTT --------|
Client                                Router --------- Server
   |-------- 100 Mbps, 80 ms RTT --------|

Let's consider a simple traffic where the client sends a request (of size inferior to an initial congestion window) and the server replies to it.
The client computes the delay between sending the request and receiving the corresponding response.
To perform the experiment with the Lowest RTT scheduler, run the following command under folder `02_scheduler/msg`:
```bash
sudo python ~/minitopo2/runner.py -t topo -x reqres_rtt
```
When inspecting the `msg_client.log` file, you can notice that all the delays are about 50 ms.
Because the Lowest RTT scheduler always prefer the faster path, and because this fast path is never blocked by the congestion window, the data only flows over the fast path.

To perform the same experiment using the Round-Robin one, do:
```bash
sudo python ~/minitopo2/runner.py -t topo -x reqres_rr
```
In this case, most of the response's delays are around 90 ms.
Since the round-robin scheduler spreads the load over the slowest network path, it causes the delay to have as lower bound the delay of this slow path.
Notice that the first request is answered in about 50 ms.
Could you figure out why?
HINT: have a look at the PCAP traces.

> Note that the multipath algorithms, including the packet scheduler, are host specific.
> This means that the client and the server can use different algorithms over a single connection.
> However, the Multipath TCP implementation in the Linux kernel does not apply `sysctl`s per namespace, making this experimentation not possible using Mininet. 


### Case 2: HTTP traffic

While the choice of the packet scheduler is important for delay-sensitive traffic, this is less obvious for bulk transfers.
Consider the following network.

   |-------- 20 Mbps, 30 ms RTT ---------|
Client                                Router --------- Server
   |-------- 20 Mbps, 100 ms RTT --------|

Our runs returned the following results (in seconds).
Yours might be different (try to run them several times), but the overal trend (and its explaination) should be similar.

|**GET Size** | 256 KB | 1 MB  | 20 MB |
|**Scheduler**|--------|-------|-------|
| Lowest RTT  | 0.246  | 0.533 | 4.912 |
| Round Robin | 0.245  | 0.582 | 4.898 |

Based on the network traces, could you explain why
- There is very little difference between schedulers with the 256 KB GET?
- The difference with larger files?

> The difference with larger files depends on when the last data on the slow path is sent.
> In such bulk scenario when networks paths fully use their congestion window, the congestion control algorithm is the limiting factor.

In the proposed HTTP experiment, a Multipath TCP connection is created for each data exchange.
Let us think about the use of a persistent Multipath TCP connection (with already established subflows) to perform the HTTP requests.
In your opinion, what will this change regarding to the results previously obtained? 

## 3. Impact of the Path Manager


- fullmesh
- ndiffports
- binder?

## 4. The notion of Backup Path
- Experiment with lost first path, second one backup

## 5. The impact of the Congestion Control Algorithm
- coupled
- cubic

## 6. Advanced Packet Scheduling with Multipath QUIC


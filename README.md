# MPTP Tutorial Hands-On

This repository is part of the [ACM SIGCOMM 2020 Tutorial on Multipath Transport Protocols](https://conferences.sigcomm.org/sigcomm/2020/tutorial-mptp.html).
More specifically, it contains the hands-on labs enabling participants to play with both Multipath TCP and Multipath QUIC.

## Prerequisites and Setup

To benefit from the hands-on, you need recent versions of the following software installed on your local computer:

* [Vagrant](https://www.vagrantup.com/docs/installation)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* [Wireshark](https://www.wireshark.org/download.html) (to be able to analyze Multipath TCP packet traces)

## VM Setup

Just run the following commands
```bash
$ vagrant up
$ vagrant ssh
```
and you will be connected to the VM.

Inside the VM, you have access to the folder containing the experiment files through the `/tutorial` folder.
To run the experiments, we rely on a bash alias called `mprun` (defined in `/etc/bash.bashrc`).
Typically, you just need to go to the right folder and run `mprun -t topo_file -x xp_file` where `topo_file` contains the description of a network scenario and `xp_file` the description of the experiment to perform.

For the remaining of this tutorial, we recommand installing `wireshark` to analyze the PCAP packet traces that will be generated each time an experiment is performed.

## 1. Observing the Bandwidth Aggregation when Using Multiple Paths

One of the use cases of multipath transport protocols is to aggregate the bandwidths of the available paths.
To demonstrate this, let's consider a simple, symmetrical network scenario.

```
   |-------- 20 Mbps, 40 ms RTT ---------|
Client                                Router --------- Server
   |-------- 20 Mbps, 40 ms RTT ---------|
```

This scenario is described in the file `01_multipath/topo`.
With this network, we will compare two `iperf` runs.
The first consists in a regular TCP transfer between the client and the server.
To perform this experiment, `ssh` into the vagrant VM using (if not done yet)
```bash
$ vagrant ssh
```
And then type the following
```bash
$ cd /tutorial/01_multipath
$ mprun -t topo -x xp_tcp
```
The run will take about 25 seconds.
When done, you can check (either on the VM or on your host machine) the content of `ìperf.log` using
```bash
$ cat iperf.log
```
You should notice that the goodput achieved by `ìperf` should be about 19-20 Mbps, which is expected since only one of the 20 Mbps network path is used.
The run should also provide you two pcap files, one from the client's perspective (`client.pcap`) and the other from the server's one (`server.pcap`).

Then, we will consider the same experiment, but running now Multipath TCP instead of plain TCP.
For this, in the vagrant VM, just type the following command in the VM.
```bash
$ mprun -t topo -x xp_mptcp
```
A quick inspection of the `iperf.log` file should indicate a goodput twice larger than with plain TCP.
This confirms that Multipath TCP can take advantage of multiple network paths (in this case, two) while TCP cannot.
You can also have a look at the pcap files to observe the usage of "Multipath TCP" TCP options.


## 2. Impact of the Selection of the Path

The packet scheduler is one of the multipath-specific algorithms.
It selects on which available subflow for sending the next packet will be sent.
The two most basic packets schedulers are the following.

* Lowest RTT first: called `default` in MPTCP, it favors the available subflow experiencing the lowest RTT.
* Round-Robin: called `roundrobin` in MPTCP, it equally shares the network load across subflows.

The packet scheduler is also responsible of the content of the data to be sent.
Yet, due to implementation constraints, most of the proposed packet schedulers in the litterature focus on the first data to be sent (i.e., they only select the path where to send the next data).
With such strategy, the scheduler has only impactful choices when several network paths are available for data transmission.


### Case 1: request/response traffic from client perspective

```
   |-------- 100 Mbps, 40 ms RTT --------|
Client                                Router --------- Server
   |-------- 100 Mbps, 80 ms RTT --------|
```

Let's consider a simple traffic where the client sends a request (of size inferior to an initial congestion window) and the server replies to it.
The client computes the delay between sending the request and receiving the corresponding response.
To perform the experiment with the Lowest RTT scheduler, run the following command under folder `02_scheduler/msg`:
```bash
$ mprun -t topo -x reqres_rtt
```
When inspecting the `msg_client.log` file, you can notice that all the delays are about 50 ms.
Because the Lowest RTT scheduler always prefer the faster path, and because this fast path is never blocked by the congestion window due to the application traffic, the data only flows over the fast path.

To perform the same experiment using the Round-Robin packet scheduler, runs:
```bash
$ mprun -t topo -x reqres_rr
```
In this case, most of the response's delays are around 90 ms.
Since the round-robin scheduler spreads the load over the slowest network path, it causes the delay to have as lower bound the delay of this slow path.

- Notice that the first request is answered in about 50 ms. Could you figure out why? HINT: have a look at the PCAP traces.

> Note that the multipath algorithms, including the packet scheduler, are host specific.
> This means that the client and the server can use different algorithms over a single connection.
> However, the Multipath TCP implementation in the Linux kernel does not apply `sysctl`s per namespace, making this experimentation not possible using Mininet. 


### Case 2: HTTP traffic

TODO: discuss rmem/wmem

While the choice of the packet scheduler is important for delay-sensitive traffic, this is less obvious for bulk transfers.
Consider the following network.

```
   |-------- 20 Mbps, 30 ms RTT ---------|
Client                                Router --------- Server
   |-------- 20 Mbps, 100 ms RTT --------|
```

On this network, the client will perform a HTTP GET request to the server for a file of varying size.
The experiences files are located in the folder `/tutorial/02_scheduler/http`.

Our runs returned the following results (in seconds).
Yours might be different (try to run them several times), but the overal trend (and its explaination) should be similar.

|**GET Size** | 256 KB | 1 MB  | 20 MB |
| :---------: | :----: | :---: | :---: |
|**Scheduler**|        |       |       |
| Lowest RTT  | 0.246  | 0.533 | 4.912 |
| Round Robin | 0.245  | 0.582 | 4.898 |

Based on the network traces, could you explain:
- Why there is very little difference between schedulers with the 256 KB GET?
- The difference with larger files?

> The difference with larger files depends on when the last data on the slow path is sent.
> In such bulk scenario when networks paths fully use their congestion window, the congestion control algorithm is the limiting factor.

In the proposed HTTP experiment, a Multipath TCP connection is created for each data exchange.
Let us think about the use of a persistent Multipath TCP connection (with already established subflows) to perform the HTTP requests.
In your opinion, what will this change regarding to the results previously obtained? 


## 3. Impact of the Path Manager

The path manager is the multipath algorithm that determines how subflows will be created over a Multipath TCP connection.
In the Linux kernel implementation, we find the following simple algorithms:

- `default`: a "passive" path manager that does not initiate any additional subflow on a connection
- `fullmesh`: the default path manager creating a subflow between each pair of (IP client, IP server)
- `ndiffports`: over the same pair of (IP client, IP server), creates several subflows (by default 2) by modifying the source port.

Notice that in Multipath TCP, only the client initiates subflows.
To understand these different algorithms, consider the following network scenario first.

```
Client ----- 25 Mbps, 20 ms RTT ------ Router --------- Server
```

Let us first consider the difference between the `fullmesh` and the `ndiffports` path managers.
Run the associated experiments (running an iperf traffic) and compare the obtained goodput.
Then, have a look at their corresponding PCAP files to spot how many subflows were created for each experiment.
```bash
$ mprun -t topo_single_path -x iperf_fullmesh
$ mprun -t topo_single_path -x iperf_ndiffports
```
In the generated PCAP traces, you should notice only one subflow for the `fullmesh` path manager, while the `ndiffports` one should generate two.

Then, let's consider the following network.
```
   |-------- 25 Mbps, 20 ms RTT --------|
Client                                Router --------- Server
   |-------- 25 Mbps, 20 ms RTT --------|
```

Now consider the three different path managers.
```bash
$ mprun -t topo_two_client_paths -x iperf_fullmesh
$ mprun -t topo_two_client_paths -x iperf_ndiffports
$ mprun -t topo_two_client_paths -x iperf_default
```

- For each of them, can you explain the results you obtain in terms of goodput (`iperf.log`) and the number of subflows created (by inspecting the PCAP traces)?

Finally, consider this network.
```
     /------ 25 Mbps, 20 ms RTT ------\    /------ 50 Mbps, 10 ms RTT ------\
Client                                Router                                 Server
     \------ 25 Mbps, 20 ms RTT ------/    \------ 50 Mbps, 10 ms RTT ------/
```
Run the experiment with the `fullmesh` path manager.
```bash
$ mprun -t topo_two_client_paths_two_server_paths -x iperf_fullmesh
```

- How many subflows are created, and between which IP address pairs?
- How does the client learn the other IP address of the server?


## 4. The Notion of Backup Path

In some situations, available network paths do not have the same cost.
They might be expensive for usage, e.g., a data-limited cellular connectivity versus a flat cost based Wi-Fi one.
Instead of preventing their usage at all, we can declare a network interface as a backup one, such that all the Multipath TCP subflows using this network interface will be marked as backup subflows.
The `default` Lowest-RTT packet scheduler considers backup subflows only if either 1) there is no non-backup subflows, or 2) all the non-backup ones are marked as potentially failed.
A subflow enters this potentially failed state when it experiences retransmissions time outs.

To better grasp this notion, consider the request/response traffic presented in the Section 2 with the network scenario shown below.
```
   |-------- 100 Mbps, 40 ms RTT --------|
Client                                Router --------- Server
   |-------- 100 Mbps, 30 ms RTT --------|
```
The connection starts on the 40 ms RTT path.
Then, after 3 seconds, the 40 ms RTT path blackholes all packets (`tc netem loss 100%`) without notifying hosts of the loss of connectivity.
This situation mimics a mobile device moving out of reachability of a wireless network.
Two versions of the topology are present in `04_backup`: `topo` (where both paths are marked as "normal") and `topo_bk` (where the 30 ms RTT path is marked as a backup one).
The experiment uses the `default` scheduler.

First run the experiment `reqres_rtt` with the topology `topo`. 
```bash
$ mprun -t topo -x reqres_rtt
```
- Have a look at the experienced application delay in `msg_client.log`. Can you explain your results?
  
Now consider the same experiment but with the topology `topo_bk`.
```bash
$ mprun -t topo_bk -x reqres_rtt
```

- How do MPTCP hosts advertise the 30 ms RTT path as a backup one?
- Look at the application delays in `msg_client.log`. Based on the client trace, can you explain the results?
- Focus on the server-side trace. Where does the server send the first response after the loss event? Can you explain why? Would it be possible for the server to decrease this application delay?


## 5. The impact of the Congestion Control Algorithm

The ability to use several network paths over a single (Multipath) TCP connection raises concerns about the fairness relative to single-path protocols (like regular TCP).
To picture this issue, consider an iperf traffic with the following network scenario.
```
Client_1 ---------- 20 Mbps, 20 ms RTT -----          -------- Server_1
         /                                  \        /
        /                                    \      /
  Client                                      Router --------- Server
        \                                    /      \
         \                                  /        \
Client_2 ---------- 20 Mbps, 80 ms RTT -----          -------- Server_2
```
Here, the main `Client` shares each of the network bottleneck with another host.
Three iperf traffics are generated.
The first flow, using Multipath TCP, is between `Client` and `Server` and lasts 50 seconds.
The second flow, using TCP, is between `Client_1` and `Server_1`, lasts 20 seconds and starts 10 seconds after the first flow.
The third flow, also using TCP, is between `Client_2` and `Server_2`, lasts 20 seconds and starts 20 seconds after the first flow.
Therefore, the first and second flows compete for the upper bottleneck between time 10s and 30s, while the first and third flow compete for the lower one between time 20s and 40s.

First consider the regular case where Multipath TCP establish one subflow per IP address pair (thus two subflows).
We compare two congestion control algorithms for the Multipath TCP flow: the regular uncoupled New Reno one (`reno`) and the coupled OLIA one (`olia`).
TCP flows use the `reno` congestion control.
You can run them in the folder `tutorial/05_congestion_control` using
```bash
$ mprun -t topo_cong -x iperf_scenario_reno_1sf
$ mprun -t topo_cong -x iperf_scenario_olia_1sf
```
Take some time to look at the results (the Multipath TCP Iperf flow result file is `iperf.log0` and TCP ones are respectively `iperf.log1` and `iperf.log2`).
You should observe that when TCP flows run, they obtain half of the bandwidth capacity of the bottleneck.
The rate that the Multipath TCP flow should obtain should 
* start to about 40 Mbps,
* then decrease to 30 Mbps after 10 seconds (competition with flow 1 on upper bottleneck),
* decrease again to 20 Mbps after 20 seconds (competing with both flows on both bottlenecks),
* increase to 30 Mbps after 30 seconds (flow 1 completed, only competing with flow 2 on lower bottleneck),
* and finally restoring the 40 Mbps after 40 seconds when both single-path flows completed.
In this situation, you should observe similar results when running `reno` and `olia`.

However, either intentional or not, several subflows of a same Multipath TCP connection might compete for the same network bottleneck.
To illustrate this case, consider the case where the Multipath TCP client creates 4 subflows between each pair of IP addresses.
Therefore, up to 5 TCP connections can compete over each bottleneck (1 regular TCP flow + 4 Multipath TCP subflows).

First run the associated `reno` experience.
```bash
$ mprun -t topo_cong -x iperf_scenario_reno_4sf
```

- Observe first the rate obtained by TCP flows (`iperf.log1` and `iperf.log2`). Then observe the rate obtained by the Multipath TCP flow (`iperf.log0`). What do you observe? Can you explain this behavior?

To prevent this possible unfairness against single-path flows, Multipath TCP can use coupled congestion control algorithms.
When using a coupled one, subflows of a same connection competing for the same bottleneck should get together as much bandwidth as a single uncoupled (TCP) flow.
Using such schemes prevent possible starvation attacks against single-path protocols.
To observe this behavior, reconsider the `olia` congestion control with the 4 subflows per IP address pair.
```bash
$ mprun -t topo_cong -x iperf_scenario_olia_4sf
```
What do you observe?

## 6. Advanced Packet Scheduling with Multipath QUIC

First case:
```
   |-------- 20 Mbps, 40 ms RTT --------|
Client                                Router --------- Server
   |-------- 20 Mbps, 80 ms RTT --------|
```

Compare SP-QUIC vs. MP-QUIC with Round-Robin and Lowest RTT schedulers.

Second case:
```
      /----- 20 Mbps, 40 ms RTT -----\
Client ----- 20 Mbps, 80 ms RTT ----- Router --------- Server
      \----- 20 Mbps, 40 ms RTT -----/
```

Compare MP-QUIC same path manager vs. MP-QUIC reverse.
Observe that first path and third paths are only used in one direction.

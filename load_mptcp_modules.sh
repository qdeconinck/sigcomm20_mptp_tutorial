# Congestion control algorithms
sudo modprobe mptcp_olia
sudo modprobe mptcp_coupled
sudo modprobe mptcp_balia
sudo modprobe mptcp_wvegas

# Schedulers
sudo modprobe mptcp_rr
sudo modprobe mptcp_redundant
# The following line will likely not work with versions of MPTCP < 0.95
sudo modprobe mptcp_blest

# Path managers
sudo modprobe mptcp_ndiffports
sudo modprobe mptcp_binder
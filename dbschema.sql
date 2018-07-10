drop table machine_list;
create table machine_list
(
	ip_address varchar(20),
	mac_address varchar(20),
	gw_address varchar(20),
	iface varchar(10),
	arpspoof_pid int,
	tcpkill_pid int,
	active boolean
);
commit;
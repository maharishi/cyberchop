begin transaction;
drop table if exists machine_list;
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
drop table if exists machine_details;
CREATE TABLE machine_details
(
	mac_address varchar(20),
	friendly_name varchar(50)
);
commit;
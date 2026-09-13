create table discount(id INT primary key, userID INT, size decimal(2,2),
constraint fk_disxount_user foreign key (userID) references "user"(id));
create table transport(id INT primary key, name varchar(255));
alter table "courier" add transportID INT,
add constraint fk_courier_transport foreign key (transportID) references transport(id);
alter table restaurant alter column	"name" set not null;
alter table restaurant add constraint name_unique unique ("name");
insert into restaurant (id,"name", address)
values (1,'puskin','lenina2'), (2,'ptica','lenina3');
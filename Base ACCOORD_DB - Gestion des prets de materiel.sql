-- Créer l'administrateur de la base
create user if not exists 'adm_accoord'@`localhost` identified by 'admlocal';

-- Créer la base de données
create database if not exists accoord_db;
grant all privileges on accoord_db.* to 'adm_accoord'@`localhost`;
flush privileges;

-- En environnement de la base
use accoord_db;


-- Retrait des contraintes pour modifications
alter table if exists materiel
	drop constraint if exists fk_categorie_materiel;

alter table if exists fiche_pret 
	drop constraint if exists fk_fiche_materiel,
	drop constraint if exists fk_fiche_emprunteur,
	drop constraint if exists fk_given_to;

alter table if exists remarque_materiel 
	drop constraint if exists fk_materiel_remarque;

alter table if exists remarque_pret
	drop constraint if exists fk_fiche_remarque;


-- Création des tables
DROP TABLE IF EXISTS MAIL_EXCHANGE;
CREATE TABLE MAIL_EXCHANGE (
	id					integer PRIMARY KEY AUTO_INCREMENT,
	mail_usrdispname	varchar(255) NOT NULL,
	mail_mail			varchar(255) NOT NULL,
	mail_firstname		varchar(255),
	mail_lastname		varchar(255)
);

create or replace table usager (
	usr_id				char(36) PRIMARY KEY DEFAULT (uuid()),
	usr_is_valid		bool NOT NULL DEFAULT TRUE,
	usr_mail			varchar(255) not null,
	usr_phone			varchar(10),
	
	constraint un_usager
		unique (usr_mail)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Utilisateurs';

create or replace table charte_pret (
	chp_date_charte		date PRIMARY KEY DEFAULT CURRENT_TIMESTAMP,
	chp_is_valide		bool not null default true,
	chp_texte			text not null
)  ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Table de la charte de prêt.';

create or replace table categorie_materiel (
	cat_id				char(36) PRIMARY KEY DEFAULT (UUID()),
	cat_label			varchar(100) not null,
	cat_prix_moyen_ht	decimal(6,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Table de regroupement des différentes catégories de matériel en prêt.';

create or replace table materiel (
	mat_id				char(36) PRIMARY KEY DEFAULT (UUID()),
	mat_label			varchar(100) not null,
	mat_cat				char(36) not null,
	mat_id_glpi			integer not null
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Table de regroupement des matériels en prêt.';

create or replace table remarque_pret (
	rmp_fch_id			char(36) not null,
	rmp_date			date not null default CURRENT_TIMESTAMP,
	rmp_texte			text not null,

	constraint pk_rmp
		primary key (rmp_fch_id, rmp_date)
)  ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Table de regroupement des remarques attachés aux prêts.';

create or replace table remarque_materiel (
	rmm_mat_id			char(36) not null,
	rmm_date			date not null default CURRENT_TIMESTAMP,
	rmm_texte			text not null,

	constraint pk_rmm
		primary key (rmm_mat_id, rmm_date)
)  ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Table de regroupement des remarques attachés aux matériels.';

create or replace table fiche_pret (
	fch_id				char(36) PRIMARY KEY DEFAULT (UUID()),
	fch_is_valid		bool NOT NULL DEFAULT TRUE,
	fch_numero			int not null auto_increment,
	fch_date			date not null default CURRENT_TIMESTAMP,
	fch_is_closed		bool not null default false,
	fch_date_pret		datetime not null,
	fch_date_ret		datetime default null,
	fch_duree			integer default 0,				/* durée prévue en semaine */
	fch_mat_id			char(36) not null,
	fch_emprunteur		char(36) not null,		/* destinataire */
	fch_given_to		char(36),				/* qui est venu le chercher */

	constraint un_fiche_num
		unique (fch_numero)
)  ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='fiche de prêt.';


-- Création des références
alter table materiel 
	add constraint fk_categorie_materiel
		foreign key( mat_cat ) references categorie_materiel ( cat_id );

alter table remarque_materiel 
	add constraint fk_materiel_remarque
		foreign key (rmm_mat_id) references materiel (mat_id);

alter table remarque_pret 
	add constraint fk_fiche_remarque
		foreign key (rmp_fch_id) references fiche_pret (fch_id);

alter table fiche_pret
	add constraint fk_fiche_materiel
		foreign key( fch_mat_id ) references materiel ( mat_id ),
	add constraint fk_fiche_emprunteur
		foreign key( fch_emprunteur ) references usager (usr_id ),
	add constraint fk_given_to
		foreign key (fch_given_to) references usager (usr_id );



-- Fixe les auto-incréments
alter table if exists fiche_pret auto_increment = 1;



-- Vues, fonctions et procédures
delimiter $$

-- Vues de travail
create or replace view vListFiche as
	select
		fFormatUser( u.usr_mail, u.usr_phone )	AS `Emprunteur`,
		fp.fch_date 					as `Date`,
		fp.fch_date_pret 				as `Date de prêt`,
		ifnull(fp.fch_date_ret,'n.a.')	as `Date de retour`,
		fp.fch_numero					as `Fiche - Numéro`,
		IF(fp.fch_is_closed,'Fermée','Ouverte')	as `Status`,
		get_rem_for(fp.fch_id,'f')		as `Fiche - Remarque :`,
		get_rem_for(fp.fch_mat_id,'m')	as `Matériel - Remarque :`,
		m2.mat_label					as `Matériel - Nom :`,
		m2.mat_id_glpi					as `Matériel - ID GLPI :`,
		cm2.cat_label					as `Matériel - Catégorie :`,
		cm2.cat_prix_moyen_ht*1.2		as `Matériel - Prix moyen :`
	from
		fiche_pret fp
		inner join materiel m2 on m2.mat_id = fp.fch_mat_id 
		inner join categorie_materiel cm2 on cm2.cat_id = m2.mat_cat
		INNER JOIN usager u ON fp.fch_emprunteur = u.usr_id 
;$$

create or replace view vListMateriel as
	select
		m.mat_id_glpi					as `ID Glpi`,
		m.mat_label						as `Matériel`,
		cm.cat_label					as `Catégorie`,
		cm.cat_prix_moyen_ht*1.2		as `Prix TTC`,
		ifnull(rm.rmm_texte,'n.a.')		as `Remarques`
	from
		materiel m
		inner join categorie_materiel cm on cm.cat_id = m.mat_cat
		left join remarque_materiel rm on rm.rmm_mat_id = m.mat_id
;$$


create or replace view vListUsager as
	select
		u.usr_mail						as `Adresse Mail`,
		fFormatPhone( u.usr_phone )		as `Téléphone`
	from
		usager u
;$$

CREATE OR REPLACE VIEW vListCategorie AS
	SELECT
		cm.cat_label 					AS `Catégorie`,
		cm.cat_prix_moyen_ht 			AS `Coût moyen`
	FROM categorie_materiel cm
;$$

CREATE OR REPLACE VIEW vReadCharte AS
	SELECT
		cp.chp_date_charte 					AS `Date de rédaction`,
		IF(cp.chp_is_valide,'Oui','Non')	AS `En cours d''utilisation`,
		cp.chp_texte						AS `Charte`
	FROM charte_pret cp
;$$


-- Récupére les remarques sur un matériel ou sur une fiche de pret
create or replace function get_rem_for( this_id char(36), tbl char(1) ) returns text
begin
	declare ret_val text;
	case lower(tbl)
		when 'm' then
			select rmm_texte into ret_val
				from remarque_materiel
				where rmm_mat_id = this_id
				ORDER BY rmm_date DESC
				limit 1;
		when 'f' then
			select rmp_texte into ret_val
			from remarque_pret
			where rmp_fch_id = this_id
			ORDER BY rmp_date DESC
			limit 1;
		else
			select '' into ret_val;
	end case;
	return ifnull(ret_val,"n.a.");
END;
$$


-- Cherche un utilisateur
/*CREATE OR REPLACE FUNCTION fLookForUser( name varchar(200) ) RETURNS ROW(
BEGIN
	SELECT
		u.*
	FROM usager u
	WHERE u.usr_mail like concat('%',name,'%');
END*/
$$

CREATE OR REPLACE FUNCTION ucfirst(str_value VARCHAR(5000)) RETURNS VARCHAR(5000)
DETERMINISTIC
BEGIN
    RETURN CONCAT(UCASE(LEFT(str_value, 1)),SUBSTRING(str_value, 2));
END
$$

CREATE OR REPLACE FUNCTION fFormatPhone( phone varchar(10) ) RETURNS varchar(15)
BEGIN
	IF
		LENGTH(phone)=10
	THEN
		RETURN concat_ws('.',
			left(phone,2),
			mid(phone,3,2),
			mid(phone,5,2),
			mid(phone,7,2),
			right(phone,2)
			);
	ELSE
		RETURN CAST( phone AS varchar(15) );
	END IF;
END;
$$

CREATE OR REPLACE FUNCTION fFormatUser( mail varchar(200), telephone varchar(10)) RETURNS varchar(150)
BEGIN
	DECLARE user_prenom varchar(50);
	DECLARE user_nom	varchar(50);
	DECLARE Full_name	varchar(100);

	SET Full_name = LEFT( mail, POSITION('@' IN mail) - 1);
	SET user_prenom = LEFT (Full_name, POSITION('.' IN Full_name)-1);
	SET user_nom = RIGHT( Full_name, length(Full_name) - POSITION('.' IN Full_name) );

	RETURN concat_ws( ' ', ucfirst(user_prenom), ucase(user_nom), '(', fFormatPhone( telephone), ')' );
END;
$$

delimiter ;


/*************************************************************/
-- Initialisation des valeurs constantes pour test
insert into usager (usr_mail, usr_phone) values
	('philippe.trichet@accoord.fr','0251927148');

insert into charte_pret values
	( '2021-01-01 01:00:00', true, 'Charte par défaut (é compléter)');

insert into categorie_materiel ( cat_label, cat_prix_moyen_ht ) values
	('Galet 4G',150.0),
	('Laptop',700.0),
	('Imprimante',120.0),
	('Téléphone mobile (sans SIM)',300.0),
	('Chargeur laptop',50.0),
	('Chargeur téléphone',11.0),
	('Ecran PC',90.0),
	('Clef WiFi',10.0),
	('Webcam',30.0);

insert into materiel (mat_label,mat_cat,mat_id_glpi) values
	('HOTSPOT-24',(select cat_id from categorie_materiel where cat_label like '%4G%'),577);

insert into fiche_pret (fch_date_pret, fch_duree, fch_mat_id, fch_emprunteur, fch_given_to) values
	('2021-04-01', 5, (select mat_id from materiel limit 1), (select usr_id from usager limit 1), (select usr_id from usager limit1));

insert into remarque_materiel (rmm_mat_id,rmm_texte) values
	((select mat_id from materiel limit 1), 'Essaie commentaire de matériel');

insert into remarque_pret (rmp_fch_id, rmp_texte) values
	((select fch_id from fiche_pret limit 1), 'Essaie commentaire de fiche de prét de matériel');

-- Chargement des données
LOAD DATA INFILE './listUsagers.csv'
-- LOAD DATA INFILE './listUsagers.csv'
	INTO TABLE MAIL_EXCHANGE
	FIELDS TERMINATED BY ","
	LINES TERMINATED BY "\n"
	IGNORE 1 ROWS
	(mail_usrdispname, @mail_mail, @mail_firstname, @mail_lastname)
	SET
		mail_lastname = LEFT( @mail_lastname, LENGTH(@mail_lastname)-1),
		mail_firstname = IF( LENGTH(@mail_firstname)=0, NULL, ucfirst(@mail_firstname)),
		mail_lastname = IF( LENGTH(@mail_lastname)<2, NULL, UCASE(@mail_lastname)),
		mail_mail = LCASE(@mail_mail) 
;

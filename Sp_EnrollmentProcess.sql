use kalum_test

create function RPAD
(
	@string varchar(MAX), -- Cadena Inicial
	@length int, --Tamaño del string final
	@pad char --Caracter que se utilizara para el reemplazo
)
returns varchar(MAX)
as
begin 
	return @string + replicate(@pad, @length - len(@string))
end

create function LPAD
(
	@string varchar(MAX),
	@length int,
	@pad char
)
returns varchar(MAX)
as
begin
	return replicate(@pad, @length - len(@string)) + @string
	end

select CONCAT('2022',dbo.LPAD('1001',4,'0'))

--Creacion de procedimientos almacenados

--Querys para consultas de datos.
select * from Aspirante
select * from CarreraTecnica
select * from InversionCarreraTecnica

insert into InversionCarreraTecnica values(NEWID(),'B64B4F67-8264-4BA7-A7EF-7AF6495CE90F',950,5,950)
insert into InversionCarreraTecnica values(NEWID(),'26FBFFD6-1A27-4E43-ADF5-366B02E75259',850,5,850)
insert into InversionCarreraTecnica values(NEWID(),'B97F2A35-C379-4101-AC60-9CEC38DB9C66',1200,5,750)

--Query para consulta de datos.
select * from Cargo

insert into Cargo values(NEWID(),'Pago de inscripcion de carrera técnica Plan fin de semana','INSCT',1200,0,0)
insert into Cargo values(NEWID(),'Pago mensual carrera técnica','PGMCT',850,0,0)
insert into Cargo values(NEWID(),'Carné','CARNE',30,0,0)

--Query para actualizar un dato de la tabla, no tomar en cuenta.
update Cargo set Descripcion = 'Pago mensual carrera técnica' where CargoId = 'B5B77E96-4BD6-486F-982F-FC7605A8E28F'

--Para borrar un procedimmiento o procedure es: drop procedure sp_EnrollmentProcess no tomar en cuenta

go
alter procedure sp_EnrollmentProcess @NoExpediente varchar(12), @Ciclo varchar(4), @MesInicioPago int, @CarreraId varchar(128)
as
begin
	--Variables para informacion de aspirantes
	declare @Apellidos varchar(128)
	declare @Nombres varchar(128)
	declare @Direccion varchar(128)
	declare @Telefono varchar(64)
	declare @Email varchar(64)
	declare @JornadaId varchar(128)
	--Variables para generar número de carné
	declare @Exists int
	declare @Carne varchar(12)
	--Variables para proceso de pago
	declare @MontoInscripcion numeric(10,2)
	declare @NumeroPagos int
	declare @MontoPago numeric(10,2)
	declare @Descripcion varchar(128)
	declare @Prefijo varchar(6)
	declare @CargoId varchar(128)
	declare @Monto numeric(10,2)
	declare @CorrelativoPagos int
	begin transaction 
	begin try
		--Se extraen datos de las tablas y se colocan en las variables temporales...
		select @Apellidos = Apellidos, @Nombres = Nombres, @Direccion = Direccion, @Telefono = Telefono, @Email = Email, @JornadaId = JornadaId   
		from Aspirante where NoExpediente = @NoExpediente
		set @Exists = (select top 1 Carne from Alumno where SUBSTRING(Carne,1,4) = @Ciclo order by Carne DESC)
		if @Exists is NULL
		begin
			set @Carne = (@Ciclo * 10000) + 1
		end
		else
		begin
			set @Carne = (select top 1 Carne from Alumno where SUBSTRING(Carne,1,4) = @Ciclo order by Carne DESC) + 1
		end
		--Proceso de Inscripción
		insert into Alumno values(@Carne, @Apellidos, @Nombres, @Direccion, @Telefono, @Email)
		insert into Inscripcion values(NEWID(),@Carne,@CarreraId,@JornadaId,@Ciclo,GETDATE())
		update Aspirante set estatus = 'INSCRITO CICLO ' + @Ciclo where NoExpediente = @NoExpediente
		--Proceso de Cargos
		--Cargo de inscripción
		select @MontoInscripcion = MontoInscripcion, @NumeroPagos = NumeroPagos, @MontoPago = MontoPago
			from InversionCarreraTecnica where CarreraId = @CarreraId
		select @CargoId = CargoId, @Descripcion = Descripcion, @Prefijo = Prefijo 
			from Cargo where CargoId = 'B5B78121-365B-4E38-913C-835F03289419'
		insert into CuentaXCobrar 
			values(CONCAT(@Prefijo,SUBSTRING(@Ciclo,3,2),dbo.lpad('1',2,'0')),@Ciclo,@Carne,@CargoId,@Descripcion,GETDATE(),GETDATE(),@MontoInscripcion,0,0)
		--Cargo de pago de Carné
		select @CargoId = CargoId, @Descripcion = Descripcion, @Prefijo = Prefijo, @Monto = Monto
			from Cargo where CargoId = '273EB6EF-B3CB-434D-AFEC-49BAB25040ED'
			insert into CuentaXCobrar 
			values(CONCAT(@Prefijo,SUBSTRING(@Ciclo,3,2),dbo.lpad('1',2,'0')),@Ciclo,@Carne,@CargoId,@Descripcion,GETDATE(),GETDATE(),@Monto,0,0)
		--Cargos Mensuales
			set @CorrelativoPagos = 1
			select @CargoId = CargoId, @Descripcion = Descripcion, @Prefijo = Prefijo from Cargo where CargoId = 'B5B77E96-4BD6-486F-982F-FC7605A8E28F'
			while(@CorrelativoPagos <= @NumeroPagos)
			begin
				insert into CuentaXCobrar 
				values(CONCAT(@Prefijo,SUBSTRING(@Ciclo,3,2),dbo.lpad(@CorrelativoPagos,2,'0')),@Ciclo,@Carne,@CargoId,@Descripcion,GETDATE(),CONCAT(@Ciclo,'-',dbo.LPAD(@MesInicioPago,2,'0'),'-','05'),@MontoPago,0,0)
				set @CorrelativoPagos = @CorrelativoPagos + 1
				set @MesInicioPago = @MesInicioPago + 1
			end
		commit transaction
		select 'TRANSACTION SUCESS' as status, @Carne as carne
	end try
	begin catch
		/*SELECT
			ERROR_NUMBER() AS ErrorNumber
			,ERROR_SEVERITY() AS ErrorSeverity
			,ERROR_STATE() AS ErrorState
			,ERROR_PROCEDURE() AS ErrorProcedure
			,ERROR_LINE() AS ErrorLine
			,ERROR_MESSAGE() AS ErrorMessage*/
		rollback transaction
		select 'TRANSACTION ERROR' as status, 0 as carne
	end catch
end


--Ejemplo para contatenar una nomenclatura INSCRIPCION + AÑO + CORRELATIVO
select CONCAT('INSC',SUBSTRING('2022',3,2),dbo.lpad('1',2,'0'))

--Query donde se sustrae una cadena de caracteres, es de ejemplo.
select SUBSTRING('2022001',1,4)

--Query de prueba para confirmar que funcione.
execute sp_EnrollmentProcess'EXP-20220003','2022',2,'B64B4F67-8264-4BA7-A7EF-7AF6495CE90F'

--Query para buscar datos
select * from Aspirante where NoExpediente = 'EXP-20220002'
select * from Alumno
select * from Inscripcion
select * from CuentaXCobrar
select * from InversionCarreraTecnica where CarreraId = 'B64B4F67-8264-4BA7-A7EF-7AF6495CE90F'
select * from Cargo
select * from CarreraTecnica
select * from CuentaXCobrar where Carne = 20220006
select * from CarreraTecnica

--Modificacion de llave primaria en CuentasXCobrar
select name from sys.key_constraints where type = 'PK' and OBJECT_NAME(parent_object_id) = N'CuentaXCobrar'
go
--Se consulta el id de la llave primaria que se va a quitar
alter table CuentaXCobrar drop constraint PK__CuentaXC__68A1C0DE1BE20104
--Se cambia la llave primaria de la tabla.
alter table CuentaXCobrar add primary key(Cargo,Anio,Carne)

--Querys para borrar datos segun examen corto
delete from Inscripcion where Carne > 0 
delete from CuentaXCobrar where Anio > 0
delete from Alumno where Carne > 0 

select * from Alumno
select * from Inscripcion
select * from CuentaXCobrar
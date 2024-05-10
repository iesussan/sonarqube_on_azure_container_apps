### Script de Configuración de SonarQube en Azure

Este script automatiza la configuración de una instancia de SonarQube en Microsoft Azure utilizando diversos servicios de Azure como Resource Groups, Storage Accounts, Key Vaults, PostgreSQL Flexible Servers y Azure Container Instances. A continuación se detalla cada sección del script.

#### Definición de Variables Globales

Variables configuradas para definir los recursos necesarios en Azure:

- `RESOURCE_GROUP`: El nombre del grupo de recursos.
- `LOCATION`: La localización del centro de datos donde se alojarán los recursos.
- `STORAGE_ACCOUNT_NAME`: El nombre de la cuenta de almacenamiento.
- `STORAGE_CONTAINER_SKU`: El tipo de SKU para la cuenta de almacenamiento.
- `KEY_VAULT_NAME`: El nombre del almacén de claves (Key Vault).
- `KEY_VAULT_SKU`: El tipo de SKU para el Key Vault.
- `CURRENT_USER_OBJECT_ID`: Obtiene el ID del usuario actualmente conectado en Azure.

#### Variables para PostgreSQL Flexible

Variables específicas para la configuración de un servidor de base de datos PostgreSQL:

- `POSTGRES_ADMIN_PASSWORD`: Contraseña del administrador de la base de datos, generada automáticamente.
- `POSTGRES_SERVER_NAME`: El nombre del servidor de PostgreSQL.
- `POSTGRES_DATABASE_NAME`: El nombre de la base de datos dentro del servidor.
- `DB_SKU_NAME`: El SKU del servidor de base de datos.
- `DB_TIER`: El nivel del servicio (por ejemplo, GeneralPurpose).
- `DB_STORAGE_SIZE`: El tamaño del almacenamiento para la base de datos.
- `DB_VERSION`: La versión de PostgreSQL a instalar.

#### Variables para Azure Container Instance (ACI)

Variables para la configuración de la instancia de contenedor donde se ejecutará SonarQube:

- `ACI_DNS_LABEL`: Etiqueta DNS única para la instancia de contenedor.
- `ACI_NAME`: Nombre de la instancia de contenedor.
- `ACI_IP_TYPE`: Tipo de dirección IP (pública en este caso).
- `ACI_OS_TYPE`: Tipo de sistema operativo del contenedor.
- `ACI_RESTART_POLICY`: Política de reinicio del contenedor.
- `ACI_CONTAINER_IMAGE`: La imagen de Docker de SonarQube a utilizar.
- `SONAR_CONTAINER_CPU`: Número de CPUs asignadas al contenedor.
- `SONAR_CONTAINER_MEMORY`: Memoria asignada al contenedor en GB.

#### Creación de Recursos y Configuración

El script realiza los siguientes pasos:

1. **Creación de un Grupo de Recursos**: Se crea un grupo de recursos donde todos los otros recursos estarán agrupados.
2. **Creación de una Cuenta de Almacenamiento**: Configuración de una cuenta de almacenamiento con varias especificaciones como versión mínima de TLS, tipo de SKU, etc.
3. **Creación de comparticiones de almacenamiento (file shares)**: Se crean varias comparticiones en la cuenta de almacenamiento para diferentes usos como datos, extensiones, registros y configuraciones.
4. **Creación y configuración de Key Vault**: Se establece un Key Vault para almacenar secretos como las credenciales de la base de datos.
5. **Creación del servidor PostgreSQL Flexible**: Se configura el servidor PostgreSQL con las variables definidas.
6. **Configuración de reglas de firewall**: Se establece una regla de firewall para permitir conexiones desde cualquier IP de Azure.
7. **Creación de la base de datos**: Se crea una base de datos específica dentro del servidor PostgreSQL.
8. **Subida de configuraciones a Azure Storage y creación de ACI**: Se sube un archivo de configuración a Azure Storage y se configura una instancia de Azure Container Instance con volúmenes y variables de entorno apropiadas.

Este script es parte de una infraestructura como código (IaC), facilitando la replicación y la gestión de la configuración en entornos de desarrollo y producción.
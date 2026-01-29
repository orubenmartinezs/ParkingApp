import csv
import uuid
import datetime
import time

# Mappings from API data
USERS = {
    "Oscar Sr.": "5102022d-6e86-4f4e-a136-22a3605a9640",
    "Oscar Jr.": "9871e842-881e-451e-848f-519277732a30"
}

ENTRY_TYPES = {
    "DIA y NOCHE": "08d4eceb-d010-4a66-89a1-752b173f3018",
    "PARTICULAR": "2168f9a2-d234-4b5e-a3a0-6b0096885ca3",
    "IBMH": "bd3c238e-832a-42a5-91b4-b9ba2d779540",
    "IDNTA": "d9d1e688-1910-4c9f-8a92-4979275ab814",
    "NOCTURNO": "nocturno", # Mapped from 'nocturno' ID in DB
    "COOD": "f28ca8ab-4b85-475b-9760-b14f0e8a42e8"
}

TARIFF_TYPES = {
    "COMPLETO": "4b939d89-d736-48a2-951a-6bdae4147c1f",
    "POR HORA": "c14a4154-bb88-4b65-90c7-1707f9518c8a",
    "MEDIO DIA": "ae72078b-2d35-4900-92ed-fd38d080090d",
    "PENSIÓN": "375390e8-15c9-40c4-ac63-bfed75ed7d17"
}

EXISTING_SUBSCRIBERS = {
    "E81-ADW": "300e0b48-6533-4699-9b0c-4c0266c590f8" # Sr. Marco Polo
}

# New subscribers to create (Plate -> ID)
new_subscribers = {}

def parse_date_time(date_str, time_str):
    # Date: DD/MM/YY
    # Time: H:MM:SS or H:MM
    if not date_str:
        return None
    
    if not time_str:
        time_str = "00:00"

    try:
        dt_str = f"{date_str} {time_str}"
        # Handle 2-digit year
        dt = datetime.datetime.strptime(dt_str, "%d/%m/%y %H:%M:%S")
    except ValueError:
        try:
             dt = datetime.datetime.strptime(dt_str, "%d/%m/%y %H:%M")
        except ValueError:
            return None
    return int(dt.timestamp() * 1000)

def clean_cost(cost_str):
    # " $30 " -> 30.0
    # " $-   " -> 0.0
    s = cost_str.replace('$', '').strip()
    if s == '-' or s == '':
        return 0.0
    try:
        return float(s)
    except:
        return 0.0

sql_lines = []
csv_file = '/Users/manzanahoria/Sites/TaranjaDigital/Parking/app/Formato_Registro_Estacionamiento_y_Pension.csv'

with open(csv_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f, delimiter=';')
    
    for row in reader:
        # SEC.;PLACA;AUTO / DESCRIPCIÓN;TIPO;FECHA ENTRADA;HORA ENTRADA;RECIBIÓ;FECHA SALIDA;HORA SALIDA;ENTREGÓ;TIEMPO;COSTO;TARIFA;COMENTARIOS
        
        plate = row['PLACA'].strip()
        desc = row['AUTO / DESCRIPCIÓN'].strip()
        tipo = row['TIPO'].strip()
        fecha_ent = row['FECHA ENTRADA'].strip()
        hora_ent = row['HORA ENTRADA'].strip()
        recibio = row['RECIBIÓ'].strip()
        fecha_sal = row['FECHA SALIDA'].strip()
        hora_sal = row['HORA SALIDA'].strip()
        entrego = row['ENTREGÓ'].strip()
        costo_str = row['COSTO'].strip()
        tarifa = row['TARIFA'].strip()
        comentarios = row['COMENTARIOS'].strip() if row['COMENTARIOS'] else ""
        
        # timestamps
        entry_time = parse_date_time(fecha_ent, hora_ent)
        exit_time = parse_date_time(fecha_sal, hora_sal)
        
        # Ensure entry_time is not None (default to 0 or exit_time if possible)
        if entry_time is None:
            if exit_time:
                entry_time = exit_time
            else:
                entry_time = int(time.time() * 1000) # Fallback to now if all else fails
        
        # IDs
        entry_user_id = USERS.get(recibio, '5102022d-6e86-4f4e-a136-22a3605a9640') # Default to Oscar Sr.
        exit_user_id = USERS.get(entrego, '5102022d-6e86-4f4e-a136-22a3605a9640')
        
        entry_type_id = ENTRY_TYPES.get(tipo, ENTRY_TYPES["PARTICULAR"])
        tariff_type_id = TARIFF_TYPES.get(tarifa, TARIFF_TYPES["POR HORA"])
        
        cost = clean_cost(costo_str)
        
        pension_subscriber_id = "NULL"
        
        # Handle Pension
        if tarifa == "PENSIÓN":
            if plate in EXISTING_SUBSCRIBERS:
                pension_subscriber_id = f"'{EXISTING_SUBSCRIBERS[plate]}'"
            else:
                # Need to create or reuse subscriber for Eliezer
                # Unique by Plate? Yes.
                if plate not in new_subscribers:
                    sub_id = str(uuid.uuid4())
                    new_subscribers[plate] = sub_id
                    
                    # Create SQL for subscriber
                    # Eliezer, entry_type from row (usually NOCTURNO)
                    now = int(time.time() * 1000)
                    sql_lines.append(f"INSERT INTO pension_subscribers (id, folio, plate, entry_type, monthly_fee, name, notes, entry_date, paid_until, is_active, is_synced, created_at, updated_at) VALUES ('{sub_id}', 0, '{plate}', '{tipo}', 1000.00, 'Eliezer', '{desc}', {now}, {now + 2592000000}, 1, 1, NOW(), NOW());")
                
                pension_subscriber_id = f"'{new_subscribers[plate]}'"
        
        # Create Record
        rec_id = str(uuid.uuid4())
        
        # Handle NULLs
        exit_time_val = exit_time if exit_time else "NULL"
        exit_user_val = f"'{exit_user_id}'" if entrego else "NULL"
        
        # Escape strings
        desc = desc.replace("'", "''")
        comentarios = comentarios.replace("'", "''")
        
        sql = f"INSERT INTO parking_records (id, folio, plate, description, client_type, entry_type_id, entry_user_id, entry_time, exit_time, cost, tariff, tariff_type_id, exit_user_id, notes, is_synced, pension_subscriber_id, created_at, updated_at) VALUES ('{rec_id}', 0, '{plate}', '{desc}', 'GENERAL', '{entry_type_id}', '{entry_user_id}', {entry_time}, {exit_time_val}, {cost}, '{tarifa}', '{tariff_type_id}', {exit_user_val}, '{comentarios}', 1, {pension_subscriber_id}, NOW(), NOW());"
        
        sql_lines.append(sql)

# Write to file
with open('/Users/manzanahoria/Sites/TaranjaDigital/Parking/app/backend/sql/import_legacy.sql', 'w', encoding='utf-8') as f:
    f.write("\n".join(sql_lines))

print("SQL generated successfully.")
SET SQL_SAFE_UPDATES = 0;

CREATE DATABASE rumah_sakit;
USE rumah_sakit;

SELECT * FROM hospital_patients;
SELECT * FROM hospital_visits;
SELECT * FROM hospital_payments;

-- lowercase
UPDATE hospital_visits
SET keluhan_text = LOWER(keluhan_text);

-- hapus spasi berlebih
UPDATE hospital_visits
SET keluhan_text = REGEXP_REPLACE(keluhan_text, '\\s+', ' ');

-- trim
UPDATE hospital_visits
SET keluhan_text = TRIM(keluhan_text);

-- normalisasi kata: 
-- stlh → setelah
UPDATE hospital_visits
SET keluhan_text = REPLACE(keluhan_text, 'stlh', 'setelah');

-- tiba tiba & tibatiba → tiba-tiba
UPDATE hospital_visits
SET keluhan_text = REPLACE(keluhan_text, 'tiba tiba', 'tiba-tiba');

UPDATE hospital_visits
SET keluhan_text = REPLACE(keluhan_text, 'tibatiba', 'tiba-tiba');

-- flu → pilek
UPDATE hospital_visits
SET keluhan_text = REPLACE(keluhan_text, 'flu', 'pilek');

-- hapus karakter aneh(tapi tetap simpan "-"
UPDATE hospital_visits
SET keluhan_text = REGEXP_REPLACE(keluhan_text, '[^a-z0-9 -]', '');

-- cleaning pembayaran
UPDATE hospital_payments
SET metode_bayar =
CASE
    WHEN LOWER(metode_bayar) IN ('cash', 'tunai')        THEN 'CASH'
    WHEN LOWER(metode_bayar) LIKE '%bpjs%'               THEN 'BPJS'
    WHEN LOWER(metode_bayar) LIKE '%asuransi%'
      OR LOWER(metode_bayar) = 'insurance'               THEN 'ASURANSI'  
    ELSE UPPER(metode_bayar)
END;

-- cleaning gender
UPDATE hospital_patients
SET gender =
CASE
    WHEN LOWER(gender) IN ('l', 'laki-laki', 'laki') THEN 'L'
    WHEN LOWER(gender) IN ('p', 'perempuan') THEN 'P'
    ELSE gender
END;

-- standarisasi nama dokter
UPDATE hospital_visits
SET doctor_name =
CASE
    WHEN REGEXP_REPLACE(LOWER(REPLACE(doctor_name, '.', '')), '\\s+', ' ') LIKE '%andi%' THEN 'Dr. Andi'
    WHEN REGEXP_REPLACE(LOWER(REPLACE(doctor_name, '.', '')), '\\s+', ' ') LIKE '%budi%' THEN 'Dr. Budi'
    WHEN REGEXP_REPLACE(LOWER(REPLACE(doctor_name, '.', '')), '\\s+', ' ') LIKE '%rina%' THEN 'Dr. Rina'
    ELSE doctor_name
END;

-- tambah kolom kategori
ALTER TABLE hospital_visits
ADD kategori VARCHAR(50);

-- kategorisasi keluhan
UPDATE hospital_visits
SET kategori =
CASE
    WHEN keluhan_text LIKE '%batuk%' 
         OR keluhan_text LIKE '%pilek%' 
         OR keluhan_text LIKE '%sesak%' 
    THEN 'Pernapasan'

    WHEN keluhan_text LIKE '%mual%' 
         OR keluhan_text LIKE '%muntah%' 
         OR keluhan_text LIKE '%diare%' 
         OR keluhan_text LIKE '%perut%' 
    THEN 'Pencernaan'

    WHEN keluhan_text LIKE '%pusing%' 
         OR keluhan_text LIKE '%migrain%' 
         OR keluhan_text LIKE '%kepala%' 
    THEN 'Neurologis'

    WHEN keluhan_text LIKE '%nyeri%' 
         OR keluhan_text LIKE '%otot%' 
         OR keluhan_text LIKE '%sendi%' 
         OR keluhan_text LIKE '%pinggang%' 
    THEN 'Muskuloskeletal'

    WHEN keluhan_text LIKE '%demam%' 
         OR keluhan_text LIKE '%menggigil%' 
    THEN 'Infeksi Umum'

    ELSE 'Lainnya'
END;

-- data quality check :
-- cek NULL
SELECT * FROM hospital_visits WHERE keluhan_text IS NULL;

-- cek duplikasi visit
SELECT visit_id, COUNT(*) 
FROM hospital_visits
GROUP BY visit_id
HAVING COUNT(*) > 1;

-- cek nilai kosong kategori
SELECT * FROM hospital_visits WHERE kategori IS NULL;

-- analisis : 
-- kategori paling sering 
SELECT kategori, COUNT(*) AS jumlah
FROM hospital_visits
GROUP BY kategori
ORDER BY jumlah DESC;

-- distribusi pembayaran per kategori
SELECT v.kategori, py.metode_bayar, COUNT(*) AS jumlah
FROM hospital_visits v
JOIN hospital_payments py ON v.visit_id = py.visit_id
GROUP BY v.kategori, py.metode_bayar
order BY v.kategori;

-- dokter dengan pasien terbanyak
SELECT doctor_name, COUNT(*) AS jumlah_pasien
FROM hospital_visits
GROUP BY doctor_name
ORDER BY jumlah_pasien DESC;

-- pola kunjungan per hari
SELECT DAYNAME(tanggal_kunjungan) AS hari, COUNT(*) AS jumlah_kunjungan
FROM hospital_visits
GROUP BY DAYNAME(tanggal_kunjungan)
ORDER BY FIELD(hari, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');

SELECT
    DAYNAME(v.tanggal_kunjungan) AS hari,
    p.metode_bayar,
    COUNT(*) AS jumlah
FROM hospital_visits v
JOIN hospital_payments p ON v.visit_id = p.visit_id
WHERE DAYNAME(v.tanggal_kunjungan) IN ('Monday', 'Saturday')
GROUP BY hari, p.metode_bayar
ORDER BY hari;

-- kategori yang paling sering pakai asuransi
SELECT v.kategori, COUNT(*) AS jumlah
FROM hospital_visits v
JOIN hospital_payments py ON v.visit_id = py.visit_id
WHERE py.metode_bayar = 'ASURANSI'
GROUP BY v.kategori
ORDER BY jumlah DESC;


-- hasil akhir
SELECT 
    p.patient_id,
    p.nama,
    p.tanggal_lahir,
    p.gender,
    
    v.visit_id,
    v.tanggal_kunjungan,
    v.doctor_name,
    v.keluhan_text,
    v.kategori,
    
    py.metode_bayar,
    py.jumlah_bayar

FROM hospital_patients p
JOIN hospital_visits v ON p.patient_id = v.patient_id
JOIN hospital_payments py ON v.visit_id = py.visit_id;

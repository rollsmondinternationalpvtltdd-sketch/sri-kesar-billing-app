CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE products(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  hsn TEXT NOT NULL,
  rate REAL NOT NULL,
  unit TEXT NOT NULL,
  gstPercent REAL NOT NULL,
  category TEXT
);

CREATE TABLE customers(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  address TEXT,
  gstin TEXT,
  phone TEXT,
  email TEXT,
  pinCode TEXT,
  placeOfSupply TEXT
);

CREATE TABLE invoices(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoiceNo TEXT NOT NULL UNIQUE,
  invoiceDate TEXT NOT NULL,
  supplierRef TEXT,
  buyerName TEXT,
  buyerAddress TEXT,
  buyerGstin TEXT,
  buyerPhone TEXT,
  buyerEmail TEXT,
  buyerPinCode TEXT,
  placeOfSupply TEXT,
  contactName TEXT,
  consigneeName TEXT,
  consigneeAddress TEXT,
  consigneeGstin TEXT,
  consigneePhone TEXT,
  consigneePinCode TEXT,
  itemsJson TEXT NOT NULL,
  pdfPath TEXT,
  updatedAt TEXT
);

CREATE TABLE drafts(
  id INTEGER PRIMARY KEY,
  invoiceJson TEXT NOT NULL,
  updatedAt TEXT NOT NULL
);

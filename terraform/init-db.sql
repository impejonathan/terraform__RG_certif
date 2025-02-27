CREATE TABLE Produit (
    ID_Produit INT PRIMARY KEY IDENTITY,
    URL_Produit VARCHAR(200),
    Prix INT,
    Info_generale VARCHAR(200),
    Descriptif VARCHAR(200),
    Note VARCHAR(50),
    Date_scrap DATE,
    Marque VARCHAR(200)
);

CREATE TABLE Caracteristiques (
    ID_Caracteristique INT PRIMARY KEY IDENTITY,
    Consommation CHAR(1),
    Indice_Pluie CHAR(1),
    Bruit INT,
    Saisonalite VARCHAR(50),
    Type_Vehicule VARCHAR(50),
    Runflat VARCHAR(50),
    ID_Produit INT FOREIGN KEY REFERENCES Produit(ID_Produit)
);

CREATE TABLE Dimensions (
    ID_Dimension INT PRIMARY KEY IDENTITY,
    Largeur INT,
    Hauteur INT,
    Diametre INT,
    Charge INT,
    Vitesse CHAR(1),
    ID_Produit INT FOREIGN KEY REFERENCES Produit(ID_Produit)
);

CREATE TABLE USER_API (
    ID_USER_API INT PRIMARY KEY IDENTITY,
    username VARCHAR(50),
    email VARCHAR(150),
    full_name VARCHAR(50),
    hashed_password VARCHAR(200),
    Date_Création DATE,
    Date_Derniere_Connexion DATE
);

CREATE TABLE DimensionsParModel (
    ID_DimensionModel INT PRIMARY KEY IDENTITY,
    Marque VARCHAR(50),
    Modele VARCHAR(50),
    Annee INT,
    Finition VARCHAR(250),
    Largeur INT,
    Hauteur INT,
    Diametre INT
);

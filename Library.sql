
CREATE TABLE IF NOT EXISTS author (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    nationality VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS book (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    publication_year INTEGER CHECK (publication_year > 0),
    genre VARCHAR(50) CHECK (genre IN ('Juvenile', 'Children', 'Adult')),
    author_id INT REFERENCES author(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS copy (
    id SERIAL PRIMARY KEY,
    book_id INT REFERENCES book(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL CHECK (status IN ('available', 'borrowed', 'reserved'))
);

CREATE TABLE IF NOT EXISTS client (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INT CHECK (age >= 0),
    contact VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS loan (
    id SERIAL PRIMARY KEY,
    copy_id INT REFERENCES copy(id) ON DELETE CASCADE,
    client_id INT REFERENCES client(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status VARCHAR(30) NOT NULL CHECK (status IN ('active', 'returned'))
);

INSERT INTO author (name, nationality) 
VALUES 
('Jane Austen', 'British'),
('Lewis Carroll', 'British'),
('Antoine de Saint-Exupéry', 'French'),
('Paulo Coelho', 'Brazilian'),
('José Saramago', 'Portuguese'),
('Chuck Palahniuk', 'American'),
('Stephen Chbosky', 'American'),
('Erika Leonard James', 'American'),
('Gillian Flynn', 'American'),
('Carla Madeira', 'Brazilian'),
('Edmundo Barreiros', 'Brazilian');

INSERT INTO book (name, publication_year, genre, author_id)
VALUES 
('Pride and Prejudice', 1813, 'Juvenile', 1),
('Persuasion', 1817, 'Juvenile', 1),
('Alice in Wonderland', 1865, 'Children', 2),
('The Little Prince', 1943, 'Children', 3),
('The Pilgrimage', 1987, 'Juvenile', 4),
('The Alchemist', 1988, 'Juvenile', 4),
('Brida', 1990, 'Juvenile', 4),
('Blindness', 1995, 'Juvenile', 5),
('Fight Club', 1996, 'Juvenile', 6),
('The Perks of Being a Wallflower', 1999, 'Juvenile', 7),
('Fifty Shades of Grey', 2011, 'Adult', 8),
('Gone Girl', 2012, 'Adult', 9),
('Everything is Rio', 2014, 'Adult', 10),
('The Captive Prince', 2023, 'Adult', 11);

INSERT INTO copy (book_id, status)
VALUES 
(1, 'available'), (2, 'available'), (3, 'borrowed'), (4, 'available'),
(5, 'borrowed'), (6, 'borrowed'), (7, 'borrowed'), (8, 'available'),
(9, 'available'), (10, 'borrowed'), (11, 'available'), (12, 'available'),
(13, 'borrowed'), (14, 'available');

INSERT INTO client (name, age, contact)
VALUES 
('Alice Santos', 22, 'alice@email.com'),
('João Pereira', 16, 'joao@email.com'),
('Maria Oliveira', 30, 'maria@email.com'),
('Antônio Silva', 10, 'antonio@email.com');

INSERT INTO loan (copy_id, client_id, date, status)
VALUES 
(10, 3, '2021-03-06', 'active'), 
(1, 1, '2022-10-30', 'returned');

CREATE OR REPLACE FUNCTION check_age_for_loan()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT c.age FROM client c WHERE c.id = NEW.client_id) < 18 
       AND (SELECT b.genre FROM book b 
            JOIN copy e ON b.id = e.book_id 
            WHERE e.id = NEW.copy_id) = 'Adult' THEN
        RAISE EXCEPTION 'Clients under 18 cannot borrow adult books';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_age
BEFORE INSERT ON loan
FOR EACH ROW
EXECUTE FUNCTION check_age_for_loan();

CREATE TABLE IF NOT EXISTS notification (
    id SERIAL PRIMARY KEY,
    book_id INT REFERENCES book(id) ON DELETE CASCADE,
    message TEXT,
    notification_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION check_book_inactivity()
RETURNS VOID AS $$
BEGIN
    INSERT INTO notification (book_id, message)
    SELECT b.id, 
           'The book "' || b.name || '" has not been borrowed in the last 6 months. Please consider either deleting it or lending it out.'
    FROM book b
    LEFT JOIN copy e ON b.id = e.book_id
    LEFT JOIN loan l ON e.id = l.copy_id
    WHERE l.date IS NULL 
       OR l.date < CURRENT_DATE - INTERVAL '6 months'
    ON CONFLICT (book_id) DO NOTHING; 
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_check_book_inactivity()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM check_book_inactivity();
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

SELECT check_book_inactivity();


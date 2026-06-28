-- books initial data
CREATE TABLE IF NOT EXISTS books (
    id       SERIAL PRIMARY KEY,
    title    VARCHAR(255) NOT NULL,
    author   VARCHAR(255) NOT NULL,
    year     INTEGER NOT NULL,
    price    DECIMAL(10,2) NOT NULL
);

INSERT INTO books (id, title, author, year, price) VALUES
(1,  'The Great Gatsby',         'F. Scott Fitzgerald',  1925, 12.99),
(2,  '1984',                     'George Orwell',        1949, 10.49),
(3,  'To Kill a Mockingbird',    'Harper Lee',           1960, 14.99),
(4,  'Pride and Prejudice',      'Jane Austen',          1813,  9.99),
(5,  'The Catcher in the Rye',   'J.D. Salinger',        1951, 11.49),
(6,  'Moby-Dick',                'Herman Melville',      1851, 13.99),
(7,  'War and Peace',            'Leo Tolstoy',          1869, 16.99),
(8,  'The Odyssey',              'Homer',                1800,  8.99),
(9,  'Crime and Punishment',     'Fyodor Dostoevsky',    1866, 12.49),
(10, 'Brave New World',          'Aldous Huxley',        1932, 11.99);

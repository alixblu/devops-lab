import { useEffect, useState } from "react";
import "./App.css";

const API_BASE = import.meta.env.VITE_API_URL || "";
const API = `${API_BASE}/api/books`;

/* ── helpers ─────────────────────────────────────────────────────── */
async function request(method, path, body) {
  const opts = {
    method,
    headers: { "Content-Type": "application/json" },
    ...(body ? { body: JSON.stringify(body) } : {}),
  };
  const res = await fetch(path, opts);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  if (res.status === 204) return null;
  return res.json();
}

/* ── empty-form default ──────────────────────────────────────────── */
const emptyForm = { title: "", author: "", year: "", price: "" };

export default function App() {
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  /* fetch list on mount */
  useEffect(() => { loadBooks(); }, []);

  /* dismiss notifications after 3s */
  useEffect(() => {
    if (error || success) {
      const t = setTimeout(() => { setError(""); setSuccess(""); }, 3000);
      return () => clearTimeout(t);
    }
  }, [error, success]);

  async function loadBooks() {
    try {
      const data = await request("GET", API);
      setBooks(data);
      setError("");
    } catch (e) {
      setError("Failed to load books: " + e.message);
    } finally {
      setLoading(false);
    }
  }

  /* ── form handlers ────────────────────────────────────────────── */
  function handleChange(e) {
    setForm({ ...form, [e.target.name]: e.target.value });
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    const payload = {
      ...form,
      year: Number(form.year) || 2000,
      price: Number(form.price) || 0,
    };
    try {
      if (editingId) {
        await request("PUT", `${API}/${editingId}/`, payload);
        setSuccess("Book updated successfully");
      } else {
        await request("POST", API, payload);
        setSuccess("Book added successfully");
      }
      setForm(emptyForm);
      setEditingId(null);
      await loadBooks();
    } catch (e) {
      setError("Save failed: " + e.message);
    }
  }

  function startEdit(book) {
    setForm({
      title: book.title,
      author: book.author,
      year: String(book.year),
      price: String(book.price),
    });
    setEditingId(book.id);
  }

  function cancelEdit() {
    setForm(emptyForm);
    setEditingId(null);
  }

  async function deleteBook(id) {
    setError("");
    try {
      await request("DELETE", `${API}/${id}/`);
      setSuccess("Book deleted");
      await loadBooks();
    } catch (e) {
      setError("Delete failed: " + e.message);
    }
  }

  /* ── render ───────────────────────────────────────────────────── */
  return (
    <div className="app">
      <h1>Book Manager</h1>

      {/* ── notifications ─────────────────────────────────────── */}
      {error && <div className="notif error">{error}</div>}
      {success && <div className="notif success">{success}</div>}

      {/* ── form ──────────────────────────────────────────────── */}
      <form onSubmit={handleSubmit} className="book-form">
        <input name="title"  placeholder="Title"  value={form.title}  onChange={handleChange} required />
        <input name="author" placeholder="Author" value={form.author} onChange={handleChange} required />
        <input name="year"   placeholder="Year"   type="number" value={form.year}   onChange={handleChange} required />
        <input name="price"  placeholder="Price"  type="number" step="0.01" value={form.price} onChange={handleChange} required />
        <button type="submit">{editingId ? "Update" : "Add"}</button>
        {editingId && <button type="button" onClick={cancelEdit}>Cancel</button>}
      </form>

      {/* ── table ─────────────────────────────────────────────── */}
      {loading ? (
        <p>Loading…</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Title</th>
              <th>Author</th>
              <th>Year</th>
              <th>Price</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {books.map((b) => (
              <tr key={b.id}>
                <td>{b.id}</td>
                <td>{b.title}</td>
                <td>{b.author}</td>
                <td>{b.year}</td>
                <td>${Number(b.price).toFixed(2)}</td>
                <td>
                  <button className="edit"  onClick={() => startEdit(b)}>Edit</button>
                  <button className="delete" onClick={() => deleteBook(b.id)}>Delete</button>
                </td>
              </tr>
            ))}
            {books.length === 0 && (
              <tr><td colSpan={6}>No books found.</td></tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}

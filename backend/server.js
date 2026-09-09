const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));

// Ensure images directory exists
const imagesDir = path.join(__dirname, 'images');
if (!fs.existsSync(imagesDir)) {
  fs.mkdirSync(imagesDir);
}

// Serve images statically
app.use('/images', express.static(imagesDir));

// MongoDB Connection (Using simple local IP or Atlas)
const mongoUri = 'mongodb://127.0.0.1:27017/women_safety_db';
mongoose.connect(mongoUri)
  .then(() => console.log('MongoDB Connected via Mongoose'))
  .catch(err => console.error('Mongoose Connection Error:', err));

// --- Schemas ---
const userSchema = new mongoose.Schema({
  name: String,
  email: String,
  phone: { type: String, unique: true },
  password: { type: String, required: true },
  role: String,
  isSafe: { type: Boolean, default: true }
});
const User = mongoose.model('User', userSchema);

const alertSchema = new mongoose.Schema({
  userId: String,
  userName: String,
  latitude: Number,
  longitude: Number,
  imageBase64List: [String],
  timestamp: { type: Date, default: Date.now }
});
const Alert = mongoose.model('Alert', alertSchema);

const contactSchema = new mongoose.Schema({
  userId: String,
  name: String,
  phone: String
});
const Contact = mongoose.model('Contact', contactSchema);

const commandSchema = new mongoose.Schema({
  userId: String,
  commandType: String,
  status: { type: String, default: 'PENDING' },
  timestamp: { type: Date, default: Date.now }
});
const Command = mongoose.model('Command', commandSchema);

// --- Routes ---

// Status Check (for browser testing)
app.get('/api', (req, res) => {
  res.send({ message: 'Women Safety API is LIVE and connected!', status: 'Healthy' });
});

// Register
app.post('/api/register', async (req, res) => {
  try {
    const user = new User(req.body);
    await user.save();
    res.status(201).send({ message: 'User registered successfully!' });
  } catch (err) {
    res.status(400).send({ error: 'User already exists or invalid data.' });
  }
});

// Update User
app.put('/api/users/:id', async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.send(user);
  } catch (err) {
    res.status(400).send({ error: 'Update failed' });
  }
});

// Update User Safety Status
app.put('/api/users/:id/safe', async (req, res) => {
  try {
    const { isSafe } = req.body;
    const user = await User.findByIdAndUpdate(req.params.id, { isSafe }, { new: true });
    res.send(user);
  } catch (err) {
    res.status(400).send({ error: 'Failed to update safety status' });
  }
});

// Delete account and all associated data
app.delete('/api/users/:id', async (req, res) => {
  try {
    const userId = req.params.id;
    const user = await User.findById(userId);
    if (!user) return res.status(404).send({ error: 'User not found' });

    // 1. Delete all ALERTS and their physical images
    const userAlerts = await Alert.find({ userId });
    for (let alert of userAlerts) {
      if (alert.imageBase64List) {
        alert.imageBase64List.forEach(imgPath => {
          const fullPath = path.join(__dirname, imgPath);
          if (fs.existsSync(fullPath)) fs.unlinkSync(fullPath);
        });
      }
    }
    await Alert.deleteMany({ userId });

    // 2. Delete all CONTACTS
    await Contact.deleteMany({ userId });

    // 3. Delete all COMMANDS
    await Command.deleteMany({ userId });

    // 4. Finally, delete the USER profile
    await User.findByIdAndDelete(userId);

    res.send({ message: 'Account and all data deleted successfully' });
  } catch (err) {
    console.error("Delete Account Error:", err);
    res.status(500).send({ error: 'Failed to delete account' });
  }
});

// Forgot/Reset Password
app.post('/api/forgot-password', async (req, res) => {
  try {
    const { phone, newPassword } = req.body;
    const user = await User.findOne({ phone });
    if (!user) return res.status(404).send({ error: 'User with this phone not found.' });

    user.password = newPassword;
    await user.save();
    res.send({ message: 'Password reset successfully' });
  } catch (err) {
    res.status(500).send({ error: 'Failed to reset password' });
  }
});

// Login
app.post('/api/login', async (req, res) => {
  try {
    let { phone, password } = req.body;
    if (!phone || !password) {
      return res.status(401).send({ error: 'Auth failed' });
    }
    phone = phone.toString().trim();
    const rawDigits = phone.replace(/\D/g, '');
    const last10 = rawDigits.length >= 10 ? rawDigits.slice(-10) : rawDigits;

    const user = await User.findOne({
      $and: [
        {
          $or: [
            { phone: phone },
            { phone: `+91${last10}` },
            { phone: `+91 ${last10}` },
            { phone: last10 }
          ]
        },
        { password: password }
      ]
    });

    if (user) {
      console.log(`✅ Login Success for user: ${user.name} (${user.phone})`);
      res.send(user);
    } else {
      console.log(`❌ Auth failed for phone: ${phone}`);
      res.status(401).send({ error: 'Auth failed' });
    }
  } catch (e) {
    console.error("Login Error:", e);
    res.status(500).send({ error: 'Server error during login' });
  }
});

// Alerts
app.post('/api/alerts', async (req, res) => {
  try {
    const { userId, userName, latitude, longitude, images, message } = req.body;
    const imageUrls = [];

    // Save each base64 image as a file
    if (images && Array.isArray(images)) {
      for (let i = 0; i < images.length; i++) {
        const base64Data = images[i];
        const fileName = `alert_${Date.now()}_${i}.jpg`;
        const filePath = path.join(imagesDir, fileName);

        // Remove base64 header if exists and write file
        const data = base64Data.replace(/^data:image\/\w+;base64,/, "");
        fs.writeFileSync(filePath, data, 'base64');

        imageUrls.push(`/images/${fileName}`);
      }
    }

    const alert = new Alert({
      userId,
      userName,
      latitude,
      longitude,
      imageBase64List: imageUrls, // Now stores file paths instead of base64
      message,
      timestamp: new Date()
    });

    await alert.save();
    res.status(201).send(alert);
  } catch (err) {
    console.error('Alert processing error:', err);
    res.status(500).send({ error: 'Failed to process alert' });
  }
});

app.get('/api/alerts', async (req, res) => {
  const alerts = await Alert.find().sort({ timestamp: -1 });
  res.send(alerts);
});

// GET Privacy-Filtered Alerts: Only alerts from users who have this guardian in their contacts
app.get('/api/alerts/guardian/:phone', async (req, res) => {
  try {
    // 1. Find all contacts that have this guardian's phone number
    const relevantContacts = await Contact.find({ phone: req.params.phone });
    const userIdsToTrack = relevantContacts.map(c => c.userId);

    // 2. Fetch alerts only for those userIds
    const alerts = await Alert.find({ userId: { $in: userIdsToTrack } }).sort({ timestamp: -1 });
    res.send(alerts);
  } catch (err) {
    res.status(500).send({ error: 'Failed to fetch private alerts' });
  }
});

app.delete('/api/alerts/:id', async (req, res) => {
  try {
    const alert = await Alert.findById(req.params.id);
    if (alert && alert.imageBase64List) {
      // Delete associated image files
      alert.imageBase64List.forEach(imgPath => {
        const fullPath = path.join(__dirname, imgPath);
        if (fs.existsSync(fullPath)) {
          fs.unlinkSync(fullPath);
        }
      });
    }
    await Alert.findByIdAndDelete(req.params.id);
    res.send({ message: 'Alert and associated images deleted' });
  } catch (err) {
    res.status(500).send({ error: 'Failed to delete alert' });
  }
});

// --- Remote Control Commands ---

// Send a Command (Guardian to User)
app.post('/api/commands', async (req, res) => {
  try {
    const { userId, commandType, guardianPhone } = req.body;

    // 1. Check if target user exists
    const user = await User.findById(userId);
    if (!user) return res.status(404).send({ error: 'User not found' });

    // 2. PRIVACY CHECK: Is the user actually in an emergency?
    if (user.isSafe) {
      return res.status(403).send({ error: 'PERMISSION_DENIED: User is currently SAFE. Remote access blocked.' });
    }

    // 3. AUTHORIZATION CHECK: Is this guardian in the user's contact list?
    if (!guardianPhone) return res.status(401).send({ error: 'Identity verification required.' });
    
    const isAuthorized = await Contact.findOne({ userId, phone: guardianPhone });
    if (!isAuthorized) {
      return res.status(403).send({ error: 'NOT_AUTHORIZED: You are not a registered guardian for this user.' });
    }

    const command = new Command(req.body);
    await command.save();
    res.status(201).send(command);
  } catch (err) {
    console.error("Command Error:", err);
    res.status(500).send({ error: 'Failed to send command' });
  }
});

// Get Pending Commands (User Polling)
app.get('/api/commands/:userId', async (req, res) => {
  try {
    const commands = await Command.find({ userId: req.params.userId, status: 'PENDING' });
    res.send(commands);
  } catch (err) {
    res.status(500).send({ error: 'Failed to poll commands' });
  }
});

// Update/Clear Command
app.put('/api/commands/:id', async (req, res) => {
  try {
    const command = await Command.findByIdAndUpdate(req.params.id, { status: 'DONE' }, { new: true });
    res.send(command);
  } catch (err) {
    res.status(400).send({ error: 'Failed to clear command' });
  }
});

// Get protected users for a guardian
app.get('/api/users/protected/:phone', async (req, res) => {
  try {
    const contacts = await Contact.find({ phone: req.params.phone });
    const userIds = contacts.map(c => c.userId);
    const users = await User.find({ _id: { $in: userIds } }, '-password'); // Don't send password
    res.send(users);
  } catch (err) {
    res.status(500).send({ error: 'Failed to fetch protected users' });
  }
});

// Contacts
app.post('/api/contacts', async (req, res) => {
  try {
    // If the app sends an empty _id string, remove it so MongoDB can generate a real one
    if (req.body._id === "") delete req.body._id;

    const contact = new Contact(req.body);
    await contact.save();
    res.status(201).send(contact);
  } catch (err) {
    console.error('Contact Save Error:', err);
    res.status(400).send({ error: 'Failed to save contact', details: err.message });
  }
});

app.get('/api/contacts/:userId', async (req, res) => {
  const contacts = await Contact.find({ userId: req.params.userId });
  res.send(contacts);
});

app.put('/api/contacts/:id', async (req, res) => {
  try {
    const contact = await Contact.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.send(contact);
  } catch (e) {
    res.status(500).send(e);
  }
});

app.delete('/api/contacts/:id', async (req, res) => {
  await Contact.findByIdAndDelete(req.params.id);
  res.send({ message: 'Deleted' });
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Node.js Server running at http://0.0.0.0:${PORT}`);
});

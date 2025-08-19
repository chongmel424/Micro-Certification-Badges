# 🎖️ Micro-Certification Badges

## 🚀 Overview

A revolutionary blockchain-based micro-certification system that allows teachers to issue NFT badges for small learning achievements. Students can stack these badges into full degrees, creating a new paradigm for education credentialing.

## ✨ Features

- 👨‍🏫 **Teacher Registration**: Authorized educators can issue badges
- 🏆 **Badge Issuance**: Create micro-certifications for specific skills
- 📚 **Subject Categorization**: Organize badges by learning subjects
- 🎓 **Degree Stacking**: Combine 5+ badges into degree certificates
- 📊 **Batch Operations**: Issue badges to multiple students simultaneously
- 🔍 **Comprehensive Querying**: Track student progress and achievements

## 🛠️ Smart Contract Functions

### 🔐 Administrative Functions

```clarity
(register-teacher (teacher principal))
```
Register a new teacher (owner only)

```clarity
(revoke-teacher (teacher principal))
```
Revoke teacher privileges (owner only)

### 🎖️ Badge Management

```clarity
(issue-badge (student principal) (title (string-ascii 50)) (subject (string-ascii 30)) (description (string-ascii 200)))
```
Issue a micro-certification badge to a student

```clarity
(batch-issue-badges (students (list 10 principal)) (title (string-ascii 50)) (subject (string-ascii 30)) (description (string-ascii 200)))
```
Issue badges to multiple students at once

### 🎓 Degree Creation

```clarity
(stack-badges-to-degree (badge-ids (list 20 uint)) (degree-title (string-ascii 50)) (field (string-ascii 30)))
```
Combine badges into a degree certificate (minimum 5 badges required)

### 📋 Query Functions

```clarity
(get-badge-info (badge-id uint))
```
Get detailed information about a specific badge

```clarity
(get-degree-info (degree-id uint))
```
Get information about a degree certificate

```clarity
(get-student-badges (student principal))
```
List all badges owned by a student

```clarity
(get-student-degrees (student principal))
```
List all degrees earned by a student

```clarity
(get-badges-by-subject (subject (string-ascii 30)))
```
Find all badges in a specific subject area

## 🎯 Usage Examples

### 1. Register as a Teacher
```bash
clarinet console
(contract-call? .Micro-Certification register-teacher 'ST1TEACHER123...)
```

### 2. Issue a Badge
```bash
(contract-call? .Micro-Certification issue-badge 
    'ST1STUDENT123... 
    "JavaScript Basics" 
    "Programming" 
    "Completed fundamental JavaScript concepts including variables, functions, and loops")
```

### 3. Stack Badges into Degree
```bash
(contract-call? .Micro-Certification stack-badges-to-degree 
    (list u1 u2 u3 u4 u5) 
    "Computer Science Degree" 
    "Technology")
```

### 4. Check Student Progress
```bash
(contract-call? .Micro-Certification get-student-badges 'ST1STUDENT123...)
(contract-call? .Micro-Certification count-student-badges 'ST1STUDENT123...)
```

## 🏗️ Development Setup

### Prerequisites
- Clarinet CLI installed
- Stacks account for testing

### Installation
```bash
git clone <repository-url>
cd Micro-Certification-Badges
clarinet check
```

### Testing
```bash
npm test
```

### Deploy
```bash
clarinet deploy --testnet
```

## 🎓 Educational Use Cases

- **🔬 STEM Courses**: Issue badges for completing lab experiments
- **💻 Coding Bootcamps**: Micro-certify specific programming skills  
- **📖 Language Learning**: Badge completion of grammar modules
- **🎨 Art Classes**: Certify mastery of different techniques
- **📈 Business Training**: Issue badges for completed modules

## 🔒 Security Features

- ✅ Teacher authorization required for badge issuance
- ✅ Badge ownership verification for degree stacking
- ✅ Immutable blockchain records
- ✅ Principal-based access control

## 📊 Contract Statistics

Track system-wide metrics:
- Total badges issued
- Total degrees awarded
- Active teachers
- Student participation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `clarinet check`
5. Submit a pull request

## 📜 License

This project is open source and available under the MIT License.

## 🌟 Future Enhancements

- 🎮 Gamification features
- 🏆 Leaderboards
- 📱 Mobile app integration
- 🌐 Cross-institution recognition
- 🔗 Integration with existing LMS platforms

---

**Built with ❤️ using Stacks and Clarity**

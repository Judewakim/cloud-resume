# ☁️ Cloud Resume

A cloud-based resume project that leverages AWS services to host and manage a professional resume with infrastructure-as-code principles.

## 🚀 Features
- **Static Website Hosting**: Uses **AWS S3** to serve a professional resume as a static website.
- **Custom Domain & HTTPS**: Configured with **Route 53** and **CloudFront** for a secure and custom domain.
- **Infrastructure as Code**: Managed using **Terraform** for easy deployment and updates.
- **Serverless Backend**: Uses **AWS Lambda** and **API Gateway** to track resume visits.
- **DynamoDB Integration**: Stores visitor count in a **DynamoDB** table.
- **CI/CD Automation**: Deploys automatically using GitHub Actions.

## 🛠️ Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) installed.
- AWS CLI configured with appropriate credentials.
- A registered domain (optional for Route 53 setup).

## 📦 Installation & Deployment
### Clone the Repository
```bash
git clone https://github.com/Judewakim/cloud-resume.git
cd cloud-resume
```

### Initialize Terraform
```bash
terraform init
```

### Preview Changes
```bash
terraform plan
```

### Deploy Infrastructure
```bash
terraform apply -auto-approve
```

### Destroy Infrastructure (Optional)
```bash
terraform destroy -auto-approve
```

## 📜 Example Output
```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.
Resume hosted successfully at https://yourcustomdomain.com
```

## 📌 Contributing
Contributions are welcome! Feel free to fork this repository and submit a pull request.

## 📜 License
This project is licensed under the MIT License.

---
💼 *Showcase your resume in the cloud!*



# Deploying using AWS Console

### Step 1: Create S3 Bucket
1. Navigate to the **S3 Console** -> **Create Bucket**.  
Enter Bucket Name -> leave rest default -> click create bucket
![create-s3](./images/create-s3.png)

### Step 2: Create DynamoDB Table
1. Navigate to the **DynamoDB Console** -> **Create Table**.  
![create-dynamodb](./images/create-dynamodb.png)

### Step 3: Create a VPC
1. Navigate to the **VPC Console** -> **Create VPC**.
2. Select **VPC and More**.
3. Provide a name for the project.
   ![vpc-1](./images/vpc-1.png)
4. Keep other settings as default.
5. Scroll down to **NAT Gateway** and select **1 per Availability Zone (AZ)**.
6. In **VPC Endpoint**, select **None**.
   ![vpc-2](./images/vpc-2.png)
7. Click **Create**.
   ![vpc-3](./images/vpc-3.png)

---

### Step 4: Create a Launch Template
1. Go to **EC2 Console** -> **Instances** -> **Launch Template**.
2. Click on **Create Launch Template**.
3. Provide a **name** and **description**.
   ![lt-1](./images/lt-1.png)
4. Select the **Amazon Machine Image (AMI)** and **Instance Type**.
   ![lt-2](./images/lt-2.png)
5. Choose a **key pair**.
6. Create a **new security group** and select the **VPC** created earlier.
7. Configure **Inbound Rules**:
   - Allow **Port 22** (SSH) from **anywhere**.
   - Allow **Port 80** (HTTP) from **anywhere**.

   ![lt-3](./images/lt-3.png)
8. Click Advanced Details -> Scroll down: now paste the script there
   ![[lt-5]](./images/lt-5.png)
8. Leave other settings as default and click **Create Launch Template**.
   ![lt-4](./images/lt-4.png)

---

### Step 5: Create an Auto Scaling Group
1. Navigate to **EC2 Console** -> **Auto Scaling** -> **Create Auto Scaling Group**.
2. Provide a **name** and select the **Launch Template** created earlier.
   ![as-1](./images/as-1.png)
3. Click **Next**.
4. In **Networking Tab**:
   - Select the created **VPC**.
   - In **Availability Zones and Subnets**, select **both private subnets**.

   ![as-2](./images/as-2.png)
5. Click **Next**.
6. In **Load Balancing**, select **No Load Balancer** (for private subnets).
   ![as-3](./images/as-3.png)
7. Set desired, minimum, and maximum instance values (as per requirement).
   ![as-4](./images/as-4.png)
8. Click **Next** -> **Review** -> **Create and Launch**.
   ![as-5](./images/as-5.png)


---

### Step 6: Verify EC2 Instances
- Go to **EC2 Console** and check if the Auto Scaling group is launching instances in private subnets.
![as-6](./images/as-6.png)

---

### Step 7: Create a Bastion Host
1. Navigate to **EC2 Console** -> **Launch Instance**.
2. Provide a **name**.
   ![bastion-1](./images/bastion-1.png)
3. Choose **Ubuntu Server** and select **Key Pair**.
   ![bastion-2](./images/bastion-2.png)
4. In **Networking**:
   - Edit and select the **VPC**.
   - Enable **Auto Assign Public IP**.
   - Select the **Security Group** (ensure SSH is allowed).

   ![bastion-3](./images/bastion-3.png)
5. Scroll down and **Launch Instance**.
   ![bastion-4](./images/bastion-4.png)
   ![bastion-5](./images/bastion-5.png)

---

### Step 8: Create a Target Group for the Load Balancer
1. Navigate to **EC2 Console** -> **Target Groups** -> **Create Target Group**.
2. Select **Target Type** as **EC2 Instance**.
3. Provide a **Target Group Name**.
   ![tg-1](./images/tg-1.png)
4. Set **Protocol** to **HTTP** and **Port 80**.
5. Select the created **VPC**.
   ![tg-2](./images/tg-2.png)
6. Next -> Select **EC2 Instances** -> Click **Include as Pending Below**.
   ![tg-3](./images/tg-3.png)
   ![tg-4](./images/tg-4.png)
7. Click **Create Target Group**.
   ![tg-5](./images/tg-5.png)

---

### Step 9: Create an Application Load Balancer (ALB)
1. Navigate to **EC2 Console** -> **Load Balancers** -> **Create Load Balancer**.
2. Select **Application Load Balancer**.
3. Set **Schema** to **Internet Facing**.
4. Select **IPv4**.
   ![alb-1](./images/alb-1.png)
5. In **Network Mapping**:
   - Select the created **VPC**.
   - Select **both Availability Zones** and the **public subnets**.

   ![alb-2](./images/alb-2.png)
6. Choose the **Security Group**.
7. In **Listeners and Routing**:
   - Set **Protocol HTTP** and **Port 80**.
   - Select the created **Target Group**.
   
   ![alb-3](./images/alb-3.png)
8. Click **Create Load Balancer**.
   ![alb-4](./images/alb-4.png)
---

### Step 9: Verify the Application
Copy the **Load Balancer DNS Name** and open it in the browser to verify.
![app-home](./images/app-home.png)

![app-config](./images/app-config.png)
---

### Step 10: Checking High Avalability
Start the stress test for the application
![app-stress-test](./images/app-stress-test.png)

Now verify the number of instances in the ec2 dashboard - They got populated for 2 to 4


---

### Note on HTTPS:
For a secure connection using HTTPS, it is recommended to configure an SSL/TLS certificate using AWS Certificate Manager (ACM). This allows the ALB to handle encrypted traffic securely, improving security and compliance.

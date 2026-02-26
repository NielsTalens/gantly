---
title: User Flows
desc: This document contains all user flows regarding the product. Think of happy flow's but also non-happy and edge cases. This set will grow and also needs to be uodated after flows change.
---

# User Flow: Adding a New Feature via Product Description

## Actor
- Product Owner

## System Actors
- Gareth (Alignment & Validation Engine)

---

## Preconditions
- Product strategy, product vision, Jobs to be done and a product description are defined and accessible

---

## Flow Overview
- The product owner opens the app and sees the automatically calculated overall alignment score indicator which is displayed at the top of the app. The indicator states the alignment is very good.
- The product owner opens the feature validator page and inputs the feature idea. 
- Gareth agents will verify alignment with all product defining documents.
- Gareth will display the conclusions, the prove and ways to improve the feature if possible.

---

## Main Flow

### 1. Add Feature Description
- Problem or opportunity
- The Product Owner adds a new feature in the feature validator.
- The description contains:
  - Goal, context, user and ways to accept/test.

---

### 2. Detect Change
- The new feature proposal is extracted and queued for evaluation.

---

### 3. Alignment Evaluation
Gareth evaluates the proposed feature against:
- Product strategy
- Product vision
- Jobs to be done (if available)
- Existing user flows (if available)
- Product description

Evaluation dimensions:
- Strategic fit
- Vision consistency
- User value clarity
- Outcome orientation

---

### 4. Gareth Responds

#### 4a. Feature Aligns — Gareth Is Proud
- Gareth is clearly pleased with the proposal.
- Gareth responds with:
  - An explicit positive reaction
  - A concise explanation of *why* the feature aligns
  - Direct references to the supporting strategy and vision elements

**Example tone**
> “This fits beautifully. It reinforces our core objective of X and directly supports the user journey we defined for Y.”

---

### 5. Create User Story
- Because the feature aligns, the system automatically:
  - Generates a user story
  - Links it to:
    - Relevant strategy and vision elements
  - Adds the user story to the backlog
  - Tags the user story with 'validated'

**Outcome**
- Feature moves seamlessly from intent to execution
- No manual translation required

---

#### 4b. Feature Does Not Align — Gareth Is Unimpressed
- Gareth is visibly unimpressed.
- Gareth responds with:
  - A clear expression of disapproval
  - A precise explanation of what is wrong
  - Specific guidance on what must change to achieve alignment

**Example tone [refine. Maybe choose Gareth modes (positive, snarky, insulting?]**
> “If I really wanted a useless feature I would have created...”

**Outcome**
- No user story is created
- Misalignment is explicit and actionable

---

## Postconditions
- Every proposed feature receives an emotional and factual alignment verdict
- Aligned features result in backlog ready user stories
- Misaligned features cannot silently progress

---

## Design Principles
- Alignment decisions are explainable and traceable
- Gareth rewards clarity and intent, not volume

---


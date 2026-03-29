const ApplicationModel = require('../models/application.model');
const NotificationModel = require('../models/notification.model');
const { query } = require('../config/database');
const { sendApplicationStatusEmail } = require('../services/email.service');

function formatInterviewDate(dateValue) {
    if (!dateValue) return null;
    const parsed = new Date(dateValue);
    if (Number.isNaN(parsed.getTime())) return null;

    return parsed.toLocaleString('en-GB', {
        weekday: 'short',
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function formatReportingDate(dateValue) {
    if (!dateValue) return null;
    const parsed = new Date(dateValue);
    if (Number.isNaN(parsed.getTime())) return null;

    return parsed.toLocaleDateString('en-GB', {
        weekday: 'long',
        day: '2-digit',
        month: 'long',
        year: 'numeric'
    });
}

function cleanTextValue(value) {
    return typeof value === 'string' ? value.trim() : '';
}

// Apply for a job
const applyForJob = async (req, res) => {
    try {
        const { job_id, cover_letter } = req.body;
        const student_id = req.user.user_id;

        const jobData = await query(
            `SELECT job_id, title, status, application_deadline
             FROM jobs
             WHERE job_id = $1`,
            [job_id]
        );

        if (jobData.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Job not found'
            });
        }

        const job = jobData.rows[0];
        const deadline = job.application_deadline
            ? new Date(job.application_deadline)
            : null;
        const isExpired = deadline && !Number.isNaN(deadline.getTime())
            ? deadline < new Date()
            : false;

        if (job.status !== 'open' || isExpired) {
            if (isExpired && job.status === 'open') {
                await query(
                    `UPDATE jobs
                     SET status = 'closed', updated_at = CURRENT_TIMESTAMP
                     WHERE job_id = $1`,
                    [job_id]
                );
            }

            return res.status(400).json({
                success: false,
                message: 'This job is closed and no longer accepting applications'
            });
        }

        // Check if already applied
        const alreadyApplied = await ApplicationModel.hasApplied(student_id, job_id);
        if (alreadyApplied) {
            return res.status(400).json({
                success: false,
                message: 'You have already applied for this job'
            });
        }

        const application = await ApplicationModel.create({
            student_id,
            job_id,
            cover_letter: cover_letter || ''
        });

        // Notify company about new application request (non-blocking)
        try {
            const companyNotificationData = await query(
                `SELECT j.company_id, j.title AS job_title, u.full_name AS student_name
                 FROM jobs j
                 JOIN users u ON u.user_id = $2
                 WHERE j.job_id = $1`,
                [job_id, student_id]
            );

            if (companyNotificationData.rows.length > 0) {
                const details = companyNotificationData.rows[0];
                await NotificationModel.create({
                    user_id: details.company_id,
                    title: '📥 New Application Request',
                    message: `**${details.student_name || 'A student'}** applied for **${details.job_title}**. Open Applications to review this request.`,
                    type: 'application'
                });
            }
        } catch (notificationError) {
            console.error('Company notification error:', notificationError);
        }

        res.status(201).json({
            success: true,
            message: 'Application submitted successfully!',
            data: application
        });
    } catch (error) {
        console.error('Apply error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to submit application',
            error: error.message
        });
    }
};

// Get my applications
const getMyApplications = async (req, res) => {
    try {
        const student_id = req.user.user_id;
        const applications = await ApplicationModel.getByStudent(student_id);
        
        res.json({
            success: true,
            data: applications
        });
    } catch (error) {
        console.error('Get applications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch applications',
            error: error.message
        });
    }
};

// Get applications for a job (Company only)
const getJobApplications = async (req, res) => {
    try {
        const { job_id } = req.params;
        const applications = await ApplicationModel.getByJob(job_id);
        
        res.json({
            success: true,
            data: applications
        });
    } catch (error) {
        console.error('Get job applications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch applications',
            error: error.message
        });
    }
};

// Get all company applications
const getCompanyApplications = async (req, res) => {
    try {
        const applications = await ApplicationModel.getByCompany(req.user.user_id);

        res.json({
            success: true,
            data: applications
        });
    } catch (error) {
        console.error('Get company applications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch company applications',
            error: error.message
        });
    }
};

// Update application status (Company only)
const updateApplicationStatus = async (req, res) => {
    try {
        const { application_id } = req.params;
        const {
            status,
            feedback,
            interview_date,
            interview_venue,
            reporting_start_date,
            reporting_end_date
        } = req.body;

        const interviewVenue = cleanTextValue(interview_venue);
        const reportingStart = reporting_start_date ? new Date(reporting_start_date) : null;
        const reportingEnd = reporting_end_date ? new Date(reporting_end_date) : null;

        if (status === 'interview') {
            if (!interview_date || !interviewVenue) {
                return res.status(400).json({
                    success: false,
                    message: 'Interview date and venue are required before sending interview updates'
                });
            }
        }

        if (status === 'accepted') {
            if (!reporting_start_date || !reporting_end_date) {
                return res.status(400).json({
                    success: false,
                    message: 'Reporting start date and end date are required before accepting an applicant'
                });
            }

            if (
                !reportingStart ||
                Number.isNaN(reportingStart.getTime()) ||
                !reportingEnd ||
                Number.isNaN(reportingEnd.getTime())
            ) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid reporting dates provided'
                });
            }

            if (reportingEnd < reportingStart) {
                return res.status(400).json({
                    success: false,
                    message: 'Reporting end date cannot be earlier than reporting start date'
                });
            }
        }
        
        // Get application details with job and company info
        const applicationDetails = await query(
            `SELECT a.*, j.title as job_title, j.company_id, c.company_name, c.company_id as company_id,
                    u.email as student_email, u.full_name as student_name
             FROM applications a
             JOIN jobs j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             JOIN users u ON a.student_id = u.user_id
             WHERE a.application_id = $1`,
            [application_id]
        );
        
        if (applicationDetails.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }
        
        const app = applicationDetails.rows[0];
        
        // Update application status
        const updated = await ApplicationModel.updateStatus(application_id, status, feedback);
        
        // Send notification to student based on status
        let title = '';
        let message = '';
        let notificationType = status;
        
        switch (status) {
            case 'shortlisted':
                title = '🎯 You have been shortlisted!';
                message = `Congratulations! You have been shortlisted for the position of **${app.job_title}** at **${app.company_name}**. The company will contact you soon for the next steps. Keep an eye on your email!`;
                break;
            case 'interview':
                title = '📅 Interview Scheduled!';
                {
                    const interviewDateLabel =
                        formatInterviewDate(interview_date) ||
                        formatInterviewDate(updated?.updated_date) ||
                        formatInterviewDate(new Date());
                    message =
                        `Great news! You have been selected for an interview for **${app.job_title}** at **${app.company_name}**.\n` +
                        `Interview Date: ${interviewDateLabel}\n` +
                        `Interview Venue: ${interviewVenue}\n` +
                        `Please report to the venue above on time and check your email for any extra instructions. Good luck!`;
                }
                break;
            case 'accepted':
                title = '🎉 You have been accepted!';
                {
                    const reportingStartLabel =
                        formatReportingDate(reporting_start_date) ||
                        formatReportingDate(reportingStart);
                    const reportingEndLabel =
                        formatReportingDate(reporting_end_date) ||
                        formatReportingDate(reportingEnd);
                    message =
                        `Congratulations! You have been accepted for the position of **${app.job_title}** at **${app.company_name}**.\n` +
                        `Reporting Period: ${reportingStartLabel} to ${reportingEndLabel}\n` +
                        `Please report between the dates above and check your email for next steps. Welcome aboard!`;
                }
                break;
            case 'rejected':
                title = '📝 Application Update';
                if (feedback && feedback.trim() !== '') {
                    message = `Thank you for applying for **${app.job_title}** at **${app.company_name}**. After careful review, we regret to inform you that your application was not successful. Feedback: "${feedback}". Keep improving your skills and apply again!`;
                } else {
                    message = `Thank you for applying for **${app.job_title}** at **${app.company_name}**. After careful review, we regret to inform you that your application was not successful. Don't give up! Keep learning and apply for other opportunities.`;
                }
                break;
            default:
                title = 'Application Update';
                message = `Your application for **${app.job_title}** at **${app.company_name}** has been updated to **${status}**.`;
        }
        
        // Create notification for student
        await NotificationModel.create({
            user_id: app.student_id,
            title: title,
            message: message,
            type: notificationType
        });

        try {
            await sendApplicationStatusEmail({
                to: app.student_email,
                studentName: app.student_name,
                title,
                message
            });
        } catch (emailError) {
            console.error('Application status email error:', emailError);
        }
        
        console.log(`Notification sent to student ${app.student_id} for status: ${status}`);
        
        res.json({
            success: true,
            message: `Application ${status === 'accepted' ? 'accepted' : status === 'rejected' ? 'rejected' : 'updated'} successfully`,
            data: updated
        });
    } catch (error) {
        console.error('Update status error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update status',
            error: error.message
        });
    }
};

module.exports = {
    applyForJob,
    getMyApplications,
    getJobApplications,
    getCompanyApplications,
    updateApplicationStatus
};

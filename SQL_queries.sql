-- Check employee job history

SELECT e.employee_id, e.first_name, e.last_name, j.job_title
FROM employees e
JOIN jobs j
JOIN job_history jh 
on jh.job_id=j.job_id
on jh.employee_id=e.employee_id
UNION ALL
SELECT e.employee_id, e.first_name, e.last_name, j.job_title
FROM employees e
JOIN jobs j
ON e.job_id=j.job_id
order by employee_id

--Create employee-job view

CREATE VIEW emp_job_view AS
SELECT e.employee_id, e.first_name, e.last_name, j.job_title
FROM employees e
JOIN jobs j
JOIN job_history jh 
on jh.job_id=j.job_id
on jh.employee_id=e.employee_id
UNION ALL
SELECT e.employee_id, e.first_name, e.last_name, j.job_title
FROM employees e
JOIN jobs j
ON e.job_id=j.job_id
order by employee_id

--Create employee-department-location view

CREATE VIEW "EMP_DEPT_LOC_VIEW" AS
SELECT l.country_id, l.city, l.state_province, d.department_name, e.first_name, e.last_name
FROM departments d
JOIN employees e
ON d.department_id=e.department_id
JOIN locations l
ON l.location_id=d.location_id

-- Create trigger for department id

CREATE OR REPLACE TRIGGER get_departments_seq_tri
BEFORE INSERT ON DEPARTMENTS for each row
BEGIN
if (:new.department_id IS NOT NULL) then
raise_application_error (
    -20001, 'The department ID number should not be assigned manually'
);
end if;
select departments_seq.nextval into :new.department_id from dual;
END;
/

-- Create trigger for employees id
CREATE OR REPLACE TRIGGER get_employees_seq_tri
BEFORE INSERT ON EMPLOYEES for each row
BEGIN
if (:new.employee_id IS NOT NULL) then
raise_application_error (
    -20001, 'The employee ID number should not be assigned manually'
);
end if;
select employees_seq.nextval into :new.employee_id from dual;
END;
/

-- Create trigger location id
CREATE OR REPLACE TRIGGER get_location_seq_tri
BEFORE INSERT ON LOCATIONS for each row
BEGIN
if (:new.location_id IS NOT NULL) then
raise_application_error (
    -20001, 'The location ID number should not be assigned manually'
);
end if;
select locations_seq.nextval into :new.location_id from dual;
END;

-- Calculate contributions towards PF
DECLARE
--variable declaration
v_basic_percent NUMBER:=45;
v_pf_percent NUMBER:=12;
v_fname VARCHAR2(15);
v_emp_sal NUMBER(10);
v_message VARCHAR2(20):= 'Hello, ';
BEGIN
SELECT first_name, salary
INTO v_fname, v_emp_sal FROM employees
WHERE employee_id=110;
dbms_output.put_line(v_message || v_fname);
dbms_output.put_line('Your salary is: ' || v_emp_sal);
dbms_output.put_line('Your contribution towards PF: ' || v_emp_sal*v_basic_percent/100*v_pf_percent/100);
END;
/

-- Assign stars based on salary
DECLARE
v_employee_id copy_emp.employee_id%type;
v_salary copy_emp.salary%type;
v_star copy_emp.star%type :=NULL;

BEGIN
v_employee_id:= :v_employee_id;

select NVL(round(salary/1000),0) into v_salary
from copy_emp where employee_id= v_employee_id;
    for i in 1..v_salary
    loop 
        v_star:= v_star ||'*';
    END LOOP;
update copy_emp set star=v_star
where employee_id=v_employee_id;
COMMIT;
END;
/

-- Create output employee_id, salary and star using cursor
DECLARE
v_employee_id copy_emp.employee_id%type;
v_salary copy_emp.salary%type;
v_star copy_emp.star%type :=NULL;
cursor c_emp_cursor is
select salary, employee_id from copy_emp;

BEGIN
OPEN c_emp_cursor;
LOOP
    FETCH c_emp_cursor into v_salary, v_employee_id;
    EXIT WHEN c_emp_cursor%NOTFOUND;
    for i in 1..NVL(ROUND(v_salary/1000),0)
    LOOP
        v_star:= v_star ||'*';
    END LOOP;
    update copy_emp set star=v_star
    where employee_id=v_employee_id;
    v_star:=NULL;
        dbms_output.put_line('Employee ID' || v_employee_id);
        dbms_output.put_line('Salary' || v_salary);
        dbms_output.put_line('Star' || v_star);
END LOOP;
END;
/

-- Determine employees due for salary raise using cursor
DECLARE
v_dept_no departments.department_id%type:= :department;

cursor c_emp_cursor is
select last_name, salary, manager_id from copy_emp 
where department_id=v_dept_no;

BEGIN
FOR emp_record in c_emp_cursor
LOOP
    if emp_record.salary < 5000 and (emp_record.manager_id = 101 OR emp_record.manager_id = 124) 
    then dbms_output.put_line(emp_record.last_name || ' Due for a raise');
    else dbms_output.put_line(emp_record.last_name || ' NOT due for a raise');
END IF;
END LOOP;
END;
/

-- Create output with employee salary and data of joining organization
declare
cursor c_sal_cursor is
select last_name, salary, hire_date from copy_emp;
v_lname varchar2(25);
v_sal number(7,2);
v_hiredate date:= to_date('02/01/1988', 'mm/dd/yyyy');

begin
if not c_sal_cursor%isopen then
    open c_sal_cursor;
end if;
fetch c_sal_cursor into v_lname, v_sal, v_hiredate;
while c_sal_cursor%found
LOOP
    if v_sal >15000 and v_hiredate>=to_date('02/01/1988', 'mm/dd/yyyy') then
    dbms_output.put_line(v_lname || ' earns ' || to_char(v_sal) || ' and joined the organization on ' || to_date(v_hiredate, 'mm/dd/yyyy'));
end if;
fetch c_sal_cursor into v_lname, v_sal, v_hiredate;
exit when c_sal_cursor%notfound;
end loop;
close c_sal_cursor;
end;


-- Determine employees due for salary raise
DECLARE
DUE_FOR_RAISE EXCEPTION;
V_HIREDATE EMPLOYEES.HIRE_DATE%TYPE;
V_LNAME EMPLOYEES.LAST_NAME%TYPE:= :lname;
V_SAL EMPLOYEES.SALARY%type;
V_YEARS NUMBER(2);

BEGIN
SELECT LAST_NAME, SALARY, HIRE_DATE 
INTO V_LNAME, V_SAL, V_HIREDATE
FROM employees WHERE LAST_NAME = V_LNAME;
V_YEARS := MONTHS_BETWEEN(SYSDATE, v_hiredate)/12;
IF v_years > 5 and v_sal < 3500 THEN
    RAISE DUE_FOR_RAISE;
ELSE
    dbms_output.put_line('Not due for a raise');
END IF;
EXCEPTION
    WHEN DUE_FOR_RAISE THEN
    INSERT INTO analysis (ename, period, sal)
    VALUES (v_lname, v_years, v_sal);
END;
/
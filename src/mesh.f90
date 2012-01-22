module mesh

  implicit none
  private

  type mesh_type
    integer :: dim = 0  ! dim = 1, 2 ,3 ~xD
    integer :: nx, nw, nn ! along-strike, along-dip, total grid number
    double precision :: dx !along-strike grid size(constant)  
    double precision :: Lfault, W, Z_CORNER ! fault length, width, lower-left corner z (follow Okada's convention)
    double precision, allocatable :: dw(:), DIP_W(:) !along-dip grid size and dip (adjustable), nw count
    double precision, allocatable :: x(:), y(:), z(:), dip(:) !coordinates and dip of every grid (nx*nw count)
  end type mesh_type

  public :: mesh_type, read_mesh, init_mesh

contains

!=============================================================
subroutine read_mesh(iin,m)

  type(mesh_type), intent(inout) :: m
  integer, intent(in) :: iin

  integer :: i

  ! problem dimension (1D, 2D or 3D), mesh type
  read(iin,*) m%dim

  !spring-block or 2d problem
  select case (m%dim)

  case(0,1)
    read(iin,*) m%nn
    read(iin,*) m%Lfault, m%W 

  case(2) !3d problem
    read(iin,*) m%nx,m%nw
    m%nn = m%nx * m%nw
    read(iin,*) m%Lfault, m%W , m%Z_CORNER 
    allocate(m%dw(m%nw), m%DIP_W(m%nw))
    do i=1,m%nw
      read(iin,*) m%dw(i), m%DIP_W(i)
    end do
  
  case default
    write(6,*) 'mesh dimension should be 0, 1 or 2'

  end select

  if (m%dim==0) m%nn = 1

end subroutine read_mesh

!=============================================================
! JPA to do: refactor: split this into several subroutines
! it should look like this:
!  select case (m%dim)
!    case(0); call init_mesh_0D(m)
!    case(1); call init_mesh_1D(m)
!    case(2); call init_mesh_2D(m)
!  end select

subroutine init_mesh(m)

  use constants, only : PI

  type(mesh_type), intent(inout) :: m

  double precision :: cd, sd, cd0, sd0
  integer :: i, j, j0

  write(6,*) 'Initializing mesh ...'

  select case (m%dim)

  ! Spring-block System
  case(0)  !; call init_mesh_0D()
    write(6,*) 'Spring-block System' 
    m%dx = m%Lfault
    m%x = 0d0

  ! 1D fault, uniform grid
  case(1) !; call init_mesh_1D()
    write(6,*) '1D fault, uniform grid' 
    m%dx = m%Lfault/m%nn
    do i=1,m%nn
      m%x(i) = (i-m%nn*0.5d0-0.5d0)*m%dx
      ! Assuming nn is even (usually a power of 2), 
      ! the center of the two middle elements (i=nn/2 and nn/2+1) 
      ! are located at x=-dx/2 and x=dx/2, respectively 
    enddo

  ! 2D fault, uniform grid along-strike
  ! Assumptions: 
  !   + the fault trace is parallel to x 
  !   + the lower "left" corner of the fault is at (0,0,Z_CORNER)
  !   + z is negative downwards (-depth)
  ! Storage scheme: faster index runs along-strike (x)
  case(2) !; call init_mesh_2D()

    write(6,*) '2D fault, uniform grid along-strike'
    m%dx = m%Lfault/m%nx
    allocate(m%y(m%nn),   &
             m%z(m%nn),   &
             m%dip(m%nn)) 

    ! set x, y, z, dip of first row
    cd = cos(m%DIP_W(1)/180d0*PI)
    sd = sin(m%DIP_W(1)/180d0*PI)
    do j = 1,m%nx
      m%x(j) = 0d0+(0.5d0+dble(j-1))*m%dx
    end do
    m%y(1:m%nx) = 0d0+0.5d0*m%dw(1)*cd
    m%z(1:m%nx) = m%Z_CORNER+0.5d0*m%dw(1)*sd
    m%dip(1:m%nx) = m%DIP_W(1)

    ! set x, y, z, dip of row 2 to nw
    do i = 2,m%nw
      cd0 = cd
      sd0 = sd
      cd = cos(m%DIP_W(i)/180d0*PI)
      sd = sin(m%DIP_W(i)/180d0*PI)
      j0 = (i-1)*m%nx
      m%x(j0+1:j0+m%nx) = m%x(1:m%nx)
      m%y(j0+1:j0+m%nx) = m%y(j0) + 0.5d0*m%dw(i-1)*cd0 + 0.5d0*m%dw(i)*cd
      m%z(j0+1:j0+m%nx) = m%z(j0) + 0.5d0*m%dw(i-1)*sd0 + 0.5d0*m%dw(i)*sd
      m%dip(j0+1:j0+m%nx) = m%DIP_W(i)
    end do

  end select

end subroutine init_mesh

end module mesh